// Services/AIService.swift
// Talks to Anthropic's Claude API for vision analysis.

import Foundation
import UIKit

@MainActor
final class AIService {

    static let shared = AIService()
    private init() {}

    // MARK: - Configuration
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let defaultModel = "claude-sonnet-4-6"
    private let fallbackModels = [
        "claude-opus-4-7",
        "claude-haiku-4-5-20251001",
        "claude-sonnet-4-5-20250929",
        "claude-opus-4-5-20251101"
    ]

    // MARK: - Tunables

    private let confidenceThreshold: Double = 0.7
    private let imagesPerBatch: Int = 5
    private let analysisImageSize = CGSize(width: 512, height: 512)

    private var apiKey: String {
        Secrets.anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasConfiguredAPIKey: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_ANTHROPIC_API_KEY_HERE"
    }

    private var preferredModel: String {
        Secrets.anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var candidateModels: [String] {
        var models = [preferredModel.isEmpty ? defaultModel : preferredModel]
        models.append(contentsOf: fallbackModels)
        return models.reduce(into: []) { uniqueModels, model in
            if !uniqueModels.contains(model) {
                uniqueModels.append(model)
            }
        }
    }

    // MARK: - Public API

    /// Analyzes photos against the user's deletion criteria.
    /// Returns ScanResults for photos that match (i.e., should be deleted).
    func analyzePhotos(
        _ photos: [PhotoAsset],
        prompt userPrompt: String
    ) async throws -> [ScanResult] {
        guard hasConfiguredAPIKey else {
            throw AIServiceError.missingAPIKey
        }

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

    func validateClaudeConnection() async throws -> AIServiceConnectionCheckResult {
        guard hasConfiguredAPIKey else {
            throw AIServiceError.missingAPIKey
        }

        var lastError: AIServiceError?

        for model in candidateModels {
            let requestBody = buildConnectionCheckRequestBody(model: model)
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

            do {
                let data = try await sendRequest(jsonData: jsonData)
                let response = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
                return AIServiceConnectionCheckResult(
                    model: model,
                    responseID: response.id
                )
            } catch let error as AIServiceError {
                lastError = error
                if case .modelUnavailable = error {
                    continue
                }
                throw error
            }
        }

        throw lastError ?? AIServiceError.invalidResponse
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
        var lastError: AIServiceError?

        for model in candidateModels {
            let requestBody = buildRequestBody(
                prompt: userPrompt,
                imagesBase64: imageData,
                model: model
            )
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

            do {
                let data = try await sendRequest(jsonData: jsonData)
                return try parseResponse(data: data, photos: photos)
            } catch let error as AIServiceError {
                lastError = error
                if case .modelUnavailable = error {
                    continue
                }
                throw error
            }
        }

        throw lastError ?? AIServiceError.invalidResponse
    }

    private func sendRequest(jsonData: Data) async throws -> Data {
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
            throw mapAPIError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }

    // MARK: - Request Construction

    func buildConnectionCheckRequestBody(model: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 1,
            "messages": [
                [
                    "role": "user",
                    "content": "Reply K."
                ]
            ]
        ]
    }

    func buildRequestBody(
        prompt: String,
        imagesBase64: [String],
        model: String
    ) -> [String: Any] {

        var content: [[String: Any]] = []

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
                "text": "Image index: \(index)"
            ])
        }

        content.append([
            "type": "text",
            "text": userPrompt(for: prompt, imageCount: imagesBase64.count)
        ])

        return [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "tools": [photoVerdictTool],
            "tool_choice": [
                "type": "tool",
                "name": "record_photo_matches"
            ],
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]
    }

    private func userPrompt(for prompt: String, imageCount: Int) -> String {
        """
        The user wants to find photos matching this cleanup description:
        "\(prompt)"

        Evaluate each image index from 0 through \(imageCount - 1). For each image,
        decide whether it clearly matches the user's description. Use the
        record_photo_matches tool with exactly one verdict per image index.
        """
    }

    private var photoVerdictTool: [String: Any] {
        [
            "name": "record_photo_matches",
            "description": """
            Records structured photo-search verdicts for FlicFinder. Use this tool
            after reviewing every provided image. Return exactly one verdict for
            every image index supplied by the user. Mark matches true only when the
            image clearly satisfies the user's cleanup description.
            """,
            "input_schema": [
                "type": "object",
                "properties": [
                    "verdicts": [
                        "type": "array",
                        "description": "One verdict for each image, in image-index order.",
                        "items": [
                            "type": "object",
                            "properties": [
                                "index": [
                                    "type": "integer",
                                    "description": "The zero-based image index."
                                ],
                                "matches": [
                                    "type": "boolean",
                                    "description": "True only when the image clearly matches the user's description."
                                ],
                                "confidence": [
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence from 0.0 to 1.0."
                                ],
                                "reason": [
                                    "type": "string",
                                    "maxLength": 80,
                                    "description": "Short user-facing reason for the verdict."
                                ]
                            ],
                            "required": ["index", "matches", "confidence", "reason"],
                            "additionalProperties": false
                        ]
                    ]
                ],
                "required": ["verdicts"],
                "additionalProperties": false
            ]
        ]
    }

    // MARK: - System Prompt

    private var systemPrompt: String {
        """
        You are a photo curator helping a user clean up their photo library.

        For each image the user provides, evaluate whether it matches their
        cleanup criteria. Be conservative: only mark matches true when the image
        clearly satisfies the user description.

        Do not identify people by name. Do not add commentary. Use the
        record_photo_matches tool exactly as requested.
        """
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data, photos: [PhotoAsset]) throws -> [ScanResult] {

        struct Verdict: Decodable {
            let index: Int
            let matches: Bool
            let confidence: Double
            let reason: String
        }

        struct ToolInput: Decodable {
            let verdicts: [Verdict]
        }

        struct AnthropicResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String
                let text: String?
                let name: String?
                let input: ToolInput?
            }
            let content: [ContentBlock]
        }

        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let toolInput = response.content.first {
            $0.type == "tool_use" && $0.name == "record_photo_matches"
        }?.input

        guard let verdicts = toolInput?.verdicts else {
            throw AIServiceError.invalidResponse
        }

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

    func mapAPIError(statusCode: Int, data: Data) -> AIServiceError {
        struct AnthropicErrorResponse: Decodable {
            struct APIError: Decodable {
                let type: String
                let message: String
            }

            let error: APIError
        }

        let decoded = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data)
        let message = decoded?.error.message

        switch statusCode {
        case 401:
            return .authenticationFailed
        case 400:
            return .apiError(message ?? "Claude rejected the request format.")
        case 404:
            return .modelUnavailable(message ?? "Claude could not find that model.")
        case 429:
            return .apiError("Claude rate limit reached. Please wait a moment and try again.")
        default:
            if let message {
                return .apiError("Claude API error \(statusCode): \(message)")
            }
            return .apiError("Claude API error \(statusCode).")
        }
    }
}

struct AIServiceConnectionCheckResult: Equatable {
    let model: String
    let responseID: String
}

private struct AnthropicMessageResponse: Decodable {
    let id: String
}

// MARK: - Errors

enum AIServiceError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case authenticationFailed
    case imageEncodingFailed
    case missingAPIKey
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Claude returned an unexpected response format."
        case .apiError(let msg): return "API error: \(msg)"
        case .authenticationFailed:
            return "Claude authentication failed. Check that your Anthropic API key is valid."
        case .imageEncodingFailed:
            return "Could not prepare the image for analysis."
        case .missingAPIKey:
            return "Add a valid Anthropic API key before using Smart Search."
        case .modelUnavailable(let msg):
            return "Claude model unavailable: \(msg)"
        }
    }
}
