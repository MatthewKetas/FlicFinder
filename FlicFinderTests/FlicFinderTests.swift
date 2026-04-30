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
    func testClaudeAPIConnectivity() async throws {
        let result = try await AIService.shared.validateClaudeConnection()

        XCTAssertFalse(result.model.isEmpty)
        XCTAssertFalse(result.responseID.isEmpty)
    }
}
