//
//  AIService.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Talks to Anthropic's Claude API for vision analysis.

import Foundation
import UIKit

@MainActor
final class AIService {

    static let shared = AIService()
    private init() {}

    // MARK: - Configuration

    // For demo: hardcode here. For production: load from Keychain or config file.
    // Make sure this file is in .gitignore if you commit your real key.
    private let apiKey: String = "YOUR_ANTHROPIC_API_KEY_HERE"
    private let model: String = "claude-opus-4-7"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - Public API

    /// Sends photos to Claude with the user's deletion criteria.
    /// Returns ScanResults marking which photos match the description.
    func analyzePhotos(
        _ photos: [PhotoAsset],
        prompt userPrompt: String
    ) async throws -> [ScanResult] {
        // TODO: Phase 4
        // 1. Load thumbnail for each photo
        // 2. Convert to base64
        // 3. Build a multi-image message
        // 4. POST to /v1/messages
        // 5. Parse JSON response into ScanResults
        return []
    }

    // MARK: - Private Helpers

    private func base64Encode(_ image: UIImage) -> String? {
        // TODO: Phase 4 — downscale to ~512px and JPEG-encode
        return nil
    }

    private func buildRequest(prompt: String, imagesBase64: [String]) -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // TODO: Phase 4 — build the JSON body with model, messages, images
        return req
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
