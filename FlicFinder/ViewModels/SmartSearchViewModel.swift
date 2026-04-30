//
//  SmartSearchViewModel.swift
//  FlicFinder
//
//  Drives the AI smart search sheet.

import Foundation
import SwiftUI

let smartSearchPhotoSelectionLimit = 5

@Observable
@MainActor
final class SmartSearchViewModel {

    // MARK: - State
    var prompt: String = ""
    var isSearching: Bool = false
    var results: [ScanResult] = []
    var errorMessage: String?

    /// Set when the user submits with too many photos selected.
    /// The view observes this to explain the limit before presenting the picker.
    var photoLimitPromptMessage: String?

    // MARK: - Services
    private let library = PhotoLibraryManager.shared
    private let ai = AIService.shared

    // MARK: - Action

    func submit(selectedPhotos: [PhotoAsset]) async {
        guard !prompt.isEmpty else { return }

        // No selection = scan a default batch of recent photos.
        let photosToAnalyze: [PhotoAsset]
        if selectedPhotos.isEmpty {
            let recent = await library.fetchAllPhotos()
            photosToAnalyze = Array(recent.prefix(smartSearchPhotoSelectionLimit))
        } else {
            photosToAnalyze = selectedPhotos
        }

        // If user picked too many, ask them to reduce the working set.
        if photosToAnalyze.count > smartSearchPhotoSelectionLimit {
            photoLimitPromptMessage = "Smart Search can analyze up to \(smartSearchPhotoSelectionLimit) photos at a time. Please select only \(smartSearchPhotoSelectionLimit) photos."
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await ai.analyzePhotos(photosToAnalyze, prompt: prompt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
