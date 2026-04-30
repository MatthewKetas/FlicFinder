//
//  ScanViewModel.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Drives the placeholder/loading UI when a quick action runs.


import Foundation
import SwiftUI

@Observable
@MainActor
final class ScanViewModel {

    // MARK: - State
    var isScanning: Bool = false
    var progress: Double = 0    // 0.0 to 1.0
    var results: [ScanResult] = []
    var errorMessage: String?

    // MARK: - Services
    private let library = PhotoLibraryManager.shared
    private let vision = VisionAnalyzer.shared

    // MARK: - Action

    func runQuickAction(_ action: QuickAction, selectedPhotos: [PhotoAsset]) async {
        isScanning = true
        progress = 0
        errorMessage = nil
        defer { isScanning = false }

        let photosToAnalyze: [PhotoAsset]
        if selectedPhotos.isEmpty {
            photosToAnalyze = await library.fetchAllPhotos()
        } else {
            photosToAnalyze = selectedPhotos
        }
        progress = 0.2

        let scanResults = await vision.analyze(photos: photosToAnalyze, action: action)
        progress = 1.0
        results = scanResults
    }
}
