// Services/AIService.swift
// Talks to Anthropic's Claude API for vision analysis.

import Foundation
import UIKit

@MainActor
final class AIService {

    static let shared = AIService()
    private init() {}

    // MARK: - Configuration
    // For demo: hardcoded here. For real apps: load from Keychain or
    // a config file in .gitignore. NEVER commit your real key to GitHub.

    private let apiKey: String = "YOUR_ANTHROPIC_API_KEY_HERE"
    private let model: String = "claude-opus-4-7"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // Tunables
    private let confidenceThreshold: Double = 0.7
    private let imagesPerBatch: Int = 5
    private let analysisImageSize = CGSize(width: 512, height: 512)

    // MARK: - Public API

    /// Analyzes photos against the user's deletion criteria.
    /// Returns ScanResults for photos that match (i.e., should be deleted).
    func analyzePhotos(
        _ photos: [PhotoAsset],
        prompt userPrompt: String
    ) async throws -> [ScanResult] {

        var allResults: [ScanResult] = []

        // Process in batches to keep individual requests small
        let batches = stride(from: 0, to: photos.count, by: imagesPerBatch).map {
            Array(photos[$0..<min($0 + imagesPerBatch, photos.count)])
        }

        for batch in batches {
            let batchResults = try await analyzeBatch(batch, prompt: userPrompt)
            allResults.append(contentsOf: batchResults)
        }

        return allResults
    }

    // MARK: - Single Batch

    private func analyzeBatch(
        _ photos: [PhotoAsset],
        prompt userPrompt: String
    ) async throws -> [ScanResult] {

        // 1. Load and encode all images
        var imageData: [String] = []
        for photo in photos {
            guard let image = await PhotoLibraryManager.shared.loadThumbnail(
                for: photo.phAsset,
                size: analysisImageSize
            ),
            let base64 = encodeImage(image) else {
                throw AIServiceError.imageEncodingFailed
            }
            imageData.append(base64)
        }

        // 2. Build the request body
        let requestBody = buildRequestBody(prompt: userPrompt, imagesBase64: imageData)
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // 3. Make the API call
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // 4. Parse the response into ScanResults
        return try parseResponse(data: data, photos: photos)
    }

    // MARK: - Request Construction

    private func buildRequestBody(prompt: String, imagesBase64: [String]) -> [String: Any] {

        // Build interleaved text + image content blocks
        var content: [[String: Any]] = []

        // Lead with the user's request
        content.append([
            "type": "text",
            "text": "The user wants to find photos matching this description: \"\(prompt)\". Below are \(imagesBase64.count) images, numbered 0 through \(imagesBase64.count - 1). Evaluate each one."
        ])

        // Add each image followed by its index label
        for (index, base64) in imagesBase64.enumerated() {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
            content.append([
                "type": "text",
                "text": "↑ Image \(index)"
            ])
        }

        return [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ],
                // Pre-fill assistant response with "[" so Claude continues a JSON array
                [
                    "role": "assistant",
                    "content": "["
                ]
            ]
        ]
    }

    // MARK: - System Prompt
    // This locks in the response format. Be specific and explicit.

    private var systemPrompt: String {
        """
        You are a photo curator helping a user clean up their photo library.

        For each image the user provides, evaluate whether it matches their \
        deletion criteria. Return your analysis as a JSON array with one object \
        per image, in the exact order the images were provided.

        Each object must have these fields:
        - "index": integer, matching the image number provided
        - "matches": boolean, true if the image matches the deletion criteria
        - "confidence": number between 0.0 and 1.0 representing how certain you are
        - "reason": brief string (under 80 characters) explaining your judgment

        Be conservative. Only mark "matches": true if you are clearly confident \
        the image matches the user's description. When in doubt, mark false.

        Return ONLY the JSON array. No preamble, no markdown code fences, no \
        explanation outside the JSON. Your response must be valid JSON that \
        can be parsed directly.
        """
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data, photos: [PhotoAsset]) throws -> [ScanResult] {

        // The Anthropic response wraps Claude's text inside a content array.
        // Structure: { "content": [ { "type": "text", "text": "..." } ] }
        struct AnthropicResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String
                let text: String?
            }
            let content: [ContentBlock]
        }

        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        guard let textBlock = response.content.first(where: { $0.type == "text" }),
              let rawText = textBlock.text else {
            throw AIServiceError.invalidResponse
        }

        // Remember: we pre-filled "[" so Claude's response is missing that opener.
        // Reconstruct the full JSON.
        var jsonString = "[" + rawText

        // Defensive cleanup: trim anything after the closing bracket if the model
        // accidentally added trailing text.
        if let endRange = jsonString.range(of: "]", options: .backwards) {
            jsonString = String(jsonString[...endRange.upperBound])
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        // Decode into our verdict structs
        struct Verdict: Decodable {
            let index: Int
            let matches: Bool
            let confidence: Double
            let reason: String
        }

        let verdicts = try JSONDecoder().decode([Verdict].self, from: jsonData)

        // Map verdicts back to photos by index, filtering for matches above threshold
        return verdicts.compactMap { verdict in
            guard verdict.matches,
                  verdict.confidence >= confidenceThreshold,
                  verdict.index >= 0,
                  verdict.index < photos.count else { return nil }

            return ScanResult(
                photo: photos[verdict.index],
                shouldDelete: true,
                confidence: verdict.confidence,
                reason: verdict.reason
            )
        }
    }

    // MARK: - Image Encoding

    private func encodeImage(_ image: UIImage) -> String? {
        // JPEG compression at 0.7 quality is a good balance — small payload,
        // still plenty of detail for visual analysis.
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
}

// MARK: - Errors

enum AIServiceError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The AI service returned an invalid response."
        case .apiError(let msg): return "API error: \(msg)"
        case .imageEncodingFailed: return "Could not prepare the image for analysis."
        }
    }
}
