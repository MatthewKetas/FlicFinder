//
//  FlicFinderTests.swift
//  FlicFinderTests
//
//  Created by Matthew Ketas on 4/2/26.
//

import XCTest
@testable import FlicFinder

final class FlicFinderTests: XCTestCase {

    @MainActor
    func testConnectionCheckRequestIsTiny() {
        let body = AIService.shared.buildConnectionCheckRequestBody(
            model: "test-model"
        )

        XCTAssertEqual(body["model"] as? String, "test-model")
        XCTAssertEqual(body["max_tokens"] as? Int, 1)
        XCTAssertNil(body["tools"])

        let messages = body["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 1)
        XCTAssertEqual(messages?.first?["content"] as? String, "Reply K.")
    }

    @MainActor
    func testSmartSearchRequestUsesStructuredToolOutput() {
        let body = AIService.shared.buildRequestBody(
            prompt: "breadboard circuit",
            imagesBase64: ["base64-image"],
            model: "test-model"
        )

        XCTAssertEqual(body["model"] as? String, "test-model")
        XCTAssertEqual(body["max_tokens"] as? Int, 1024)

        let toolChoice = body["tool_choice"] as? [String: String]
        XCTAssertEqual(toolChoice?["type"], "tool")
        XCTAssertEqual(toolChoice?["name"], "record_photo_matches")

        let tools = body["tools"] as? [[String: Any]]
        let tool = tools?.first
        XCTAssertEqual(tool?["name"] as? String, "record_photo_matches")

        let inputSchema = tool?["input_schema"] as? [String: Any]
        let required = inputSchema?["required"] as? [String]
        XCTAssertEqual(required, ["verdicts"])

        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["type"] as? String, "image")
        XCTAssertEqual(content?[1]["text"] as? String, "Image index: 0")
        XCTAssertTrue(
            (content?.last?["text"] as? String)?.contains("breadboard circuit") == true
        )
    }

    @MainActor
    func testModel404MapsToModelUnavailableError() {
        let response = """
        {
          "type": "error",
          "error": {
            "type": "not_found_error",
            "message": "model: missing-model"
          }
        }
        """.data(using: .utf8)!

        let error = AIService.shared.mapAPIError(statusCode: 404, data: response)

        guard case .modelUnavailable(let message) = error else {
            return XCTFail("Expected modelUnavailable, got \(error)")
        }

        XCTAssertEqual(message, "model: missing-model")
    }

    @MainActor
    func testClaudeAPIConnectivityMakesTinyRequest() async throws {
        let result = try await AIService.shared.validateClaudeConnection()

        XCTAssertFalse(result.model.isEmpty)
        XCTAssertFalse(result.responseID.isEmpty)
    }
}
