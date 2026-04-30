// Services/VisionAnalyzer.swift
// On-device ML using Apple's Vision and Core Image frameworks.

import Foundation
import Vision
import UIKit
import CoreImage
import Photos

@MainActor
final class VisionAnalyzer {

    static let shared = VisionAnalyzer()
    private init() {}

    // Reuse one Core Image context — creating one is expensive.
    // nonisolated because Core Image is thread-safe.
    private let ciContext = CIContext(options: nil)

    // MARK: - Tunable Thresholds
    // These are the knobs you'll adjust based on testing with your own photos.

    /// Blur scores below this are considered blurry. Higher = stricter (fewer flags).
    private let blurThreshold: Double = 200.0

    /// Confidence required to flag a screenshot. 0.0–1.0.
    private let screenshotConfidenceThreshold: Float = 0.7

    /// Feature-print distance below which two photos are considered duplicates.
    /// Lower = more similar. Range is roughly 0.0–10.0.
    private let duplicateDistanceThreshold: Float = 0.4

    // MARK: - Public API

    func detectBlurry(in photos: [PhotoAsset]) async -> [ScanResult] {
        var results: [ScanResult] = []

        for photo in photos {
            guard let image = await loadAnalysisImage(for: photo) else { continue }
            let score = blurScore(for: image)

            if score < blurThreshold {
                results.append(ScanResult(
                    photo: photo,
                    shouldDelete: true,
                    confidence: 1.0 - (score / blurThreshold),
                    reason: "Blurry (sharpness score: \(Int(score)))"
                ))
            }
        }
        return results
    }

    func detectScreenshots(in photos: [PhotoAsset]) async -> [ScanResult] {
        var results: [ScanResult] = []

        for photo in photos {
            // Quick win: PHAsset has a screenshot subtype already!
            // We can skip Vision entirely if Apple already tagged it.
            if photo.phAsset.mediaSubtypes.contains(.photoScreenshot) {
                results.append(ScanResult(
                    photo: photo,
                    shouldDelete: true,
                    confidence: 1.0,
                    reason: "Tagged as screenshot by iOS"
                ))
                continue
            }

            // Otherwise fall back to image classification
            guard let image = await loadAnalysisImage(for: photo),
                  let confidence = classifyAsScreenshot(image) else { continue }

            if confidence >= screenshotConfidenceThreshold {
                results.append(ScanResult(
                    photo: photo,
                    shouldDelete: true,
                    confidence: Double(confidence),
                    reason: "Looks like a screenshot"
                ))
            }
        }
        return results
    }

    func findDuplicates(in photos: [PhotoAsset]) async -> [ScanResult] {
        // Step 1: compute a feature print for each photo
        var prints: [(photo: PhotoAsset, print: VNFeaturePrintObservation)] = []
        for photo in photos {
            guard let image = await loadAnalysisImage(for: photo),
                  let fp = featurePrint(for: image) else { continue }
            prints.append((photo, fp))
        }

        // Step 2: pairwise distance comparison
        // O(n²) — fine for hundreds, slow for thousands. Real production apps
        // would use locality-sensitive hashing; for a demo this is plenty.
        var flaggedIDs: Set<String> = []
        var results: [ScanResult] = []

        for i in 0..<prints.count {
            // If we've already flagged this photo as a duplicate of an earlier one,
            // don't compare it against later ones — keep the chain simple.
            if flaggedIDs.contains(prints[i].photo.id) { continue }

            for j in (i + 1)..<prints.count {
                if flaggedIDs.contains(prints[j].photo.id) { continue }

                var distance: Float = 0
                do {
                    try prints[i].print.computeDistance(&distance, to: prints[j].print)
                } catch {
                    continue
                }

                if distance < duplicateDistanceThreshold {
                    // Keep the one taken first (i), flag the later one (j) for deletion
                    flaggedIDs.insert(prints[j].photo.id)
                    results.append(ScanResult(
                        photo: prints[j].photo,
                        shouldDelete: true,
                        confidence: Double(1.0 - (distance / duplicateDistanceThreshold)),
                        reason: "Near-duplicate of an earlier photo"
                    ))
                }
            }
        }
        return results
    }

    func findOldPhotos(
        in photos: [PhotoAsset],
        olderThan years: Int = 3
    ) async -> [ScanResult] {
        let cutoff = Calendar.current.date(
            byAdding: .year,
            value: -years,
            to: Date()
        ) ?? Date()

        return photos
            .filter { ($0.creationDate ?? Date()) < cutoff }
            .map { photo in
                ScanResult(
                    photo: photo,
                    shouldDelete: false,    // user decides
                    confidence: 1.0,
                    reason: "Older than \(years) years"
                )
            }
    }

    func analyze(
        photos: [PhotoAsset],
        action: QuickAction
    ) async -> [ScanResult] {
        switch action {
        case .blurry:      return await detectBlurry(in: photos)
        case .screenshots: return await detectScreenshots(in: photos)
        case .duplicates:  return await findDuplicates(in: photos)
        case .oldPhotos:   return await findOldPhotos(in: photos)
        }
    }

    // MARK: - Private: Image Loading
    // We use a smaller image size for analysis to keep things fast.
    // 512px is enough for the classifier and feature print to work well.

    private func loadAnalysisImage(for photo: PhotoAsset) async -> UIImage? {
        let library = PhotoLibraryManager.shared
        return await library.loadThumbnail(
            for: photo.phAsset,
            size: CGSize(width: 512, height: 512)
        )
    }

    // MARK: - Private: Blur Detection
    // Algorithm: apply Laplacian (edge-detection) filter, measure variance.
    // Sharp images have many edges = high variance. Blurry images = low variance.

    private func blurScore(for image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return Double.infinity }
        let ciImage = CIImage(cgImage: cgImage)

        // Apply Laplacian filter
        guard let laplacian = CIFilter(name: "CIConvolution3X3") else {
            return Double.infinity
        }
        laplacian.setValue(ciImage, forKey: kCIInputImageKey)
        // Standard 3x3 Laplacian kernel (edge detector)
        laplacian.setValue(
            CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9),
            forKey: "inputWeights"
        )

        guard let output = laplacian.outputImage else { return Double.infinity }

        // Measure variance using CIAreaAverage on the squared output
        guard let stats = CIFilter(name: "CIAreaAverage") else {
            return Double.infinity
        }
        stats.setValue(output, forKey: kCIInputImageKey)
        stats.setValue(CIVector(cgRect: output.extent), forKey: kCIInputExtentKey)

        guard let avgImage = stats.outputImage else { return Double.infinity }

        // Render the 1x1 average pixel into a buffer and read its value
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avgImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Average of RGB channels — proxy for edge magnitude / variance
        let r = Double(pixel[0])
        let g = Double(pixel[1])
        let b = Double(pixel[2])
        return (r + g + b) / 3.0 * 10.0  // scale up so threshold ~200 makes sense
    }

    // MARK: - Private: Screenshot Classification

    private func classifyAsScreenshot(_ image: UIImage) -> Float? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else { return nil }

        // Find the screenshot label specifically
        let screenshotObs = observations.first { $0.identifier == "screenshot" }
        return screenshotObs?.confidence
    }

    // MARK: - Private: Feature Prints (for duplicate detection)

    private func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        return request.results?.first as? VNFeaturePrintObservation
    }
}
