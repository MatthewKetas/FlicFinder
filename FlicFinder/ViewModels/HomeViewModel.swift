//
//  HomeViewModel.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Owns the state for ContentView (the home screen).

import Foundation
import SwiftUI

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - Published State
    var totalPhotos: Int = 0
    var totalLibrarySize: Int64 = 0
    var spaceSaved: Int64 = 0
    var photosCleaned: Int = 0
    var isLoading: Bool = false
    var permissionDenied: Bool = false

    // MARK: - Services
    private let library = PhotoLibraryManager.shared

    // MARK: - Persistence keys (for the running counter)
    private let savedSpaceKey = "photoSweep.spaceSaved"
    private let cleanedKey = "photoSweep.photosCleaned"

    init() {
        // Load persisted counters
        spaceSaved = Int64(UserDefaults.standard.integer(forKey: savedSpaceKey))
        photosCleaned = UserDefaults.standard.integer(forKey: cleanedKey)
    }

    // MARK: - Actions

    func onAppear() async {
        isLoading = true
        defer { isLoading = false }

        let granted = await library.requestAuthorization()
        guard granted else {
            permissionDenied = true
            return
        }
        await refreshStats()
    }

    func refreshStats() async {
        let assets = await library.fetchAllPhotos()
        totalPhotos = assets.count
        totalLibrarySize = assets.reduce(0) { $0 + $1.fileSize }
    }

    func recordDeletion(freedBytes: Int64, photoCount: Int) {
        spaceSaved += freedBytes
        photosCleaned += photoCount

        UserDefaults.standard.set(Int(spaceSaved), forKey: savedSpaceKey)
        UserDefaults.standard.set(photosCleaned, forKey: cleanedKey)

        Task { await refreshStats() }
    }

    // MARK: - Formatted Outputs

    var formattedSpaceSaved: String {
        ByteCountFormatter.string(fromByteCount: spaceSaved, countStyle: .file)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalLibrarySize, countStyle: .file)
    }
}
