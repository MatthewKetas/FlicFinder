//
//  SmartSearchViewModel.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Drives the AI smart search sheet.


import Foundation
import SwiftUI

@Observable
@MainActor
final class SmartSearchViewModel {

    // MARK: - State
    var prompt: String = ""
    var isSearching: Bool = false
    var results: [ScanResult] = []
    var errorMessage: String?

    // MARK: - Services
    private let library = PhotoLibraryManager.shared
    private let ai = AIService.shared

    // MARK: - Action

    func submit() async {
        guard !prompt.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let allPhotos = await library.fetchAllPhotos()
            // For demo speed, only analyze a recent batch
            let batch = Array(allPhotos.prefix(50))
            results = try await ai.analyzePhotos(batch, prompt: prompt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
