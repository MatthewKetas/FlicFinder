//
//  VisionAnalyzer.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// On-device ML using Apple's Vision framework.
// Stubs for now — we implement the actual logic in Phase 3.

import Foundation
import Vision
import UIKit

@MainActor
final class VisionAnalyzer {

    static let shared = VisionAnalyzer()
    private init() {}

    // MARK: - Blur Detection

    func detectBlurry(in photos: [PhotoAsset]) async -> [ScanResult] {
        // TODO: Phase 3 — Laplacian variance via CIImage
        // Lower variance = more blur
        return []
    }

    // MARK: - Screenshot Detection

    func detectScreenshots(in photos: [PhotoAsset]) async -> [ScanResult] {
        // TODO: Phase 3 — VNClassifyImageRequest, filter for "screenshot"
        return []
    }

    // MARK: - Near-Duplicate Finder

    func findDuplicates(in photos: [PhotoAsset]) async -> [ScanResult] {
        // TODO: Phase 3 — VNFeaturePrintObservation, pairwise distance
        return []
    }

    // MARK: - Old Photos

    func findOldPhotos(
        in photos: [PhotoAsset],
        olderThan years: Int = 3
    ) async -> [ScanResult] {
        // No ML needed — just date filtering.
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

    // MARK: - Dispatcher
    /// Convenience method that picks the right analyzer for a quick action.
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
}
