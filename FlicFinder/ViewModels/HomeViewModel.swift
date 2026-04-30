// ViewModels/HomeViewModel.swift
// Owns the state for ContentView (the home screen).

import Foundation
import SwiftUI
import PhotosUI

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - Library Stats
    var totalPhotos: Int = 0          // total count in user's library (still tracked internally)
    var totalLibrarySize: Int64 = 0
    var spaceSaved: Int64 = 0
    var photosCleaned: Int = 0
    var isLoading: Bool = false
    var permissionDenied: Bool = false
    var selectionErrorMessage: String?

    // MARK: - User Selection (persists across launches)
    /// The user's chosen working set — survives app relaunch.
    var selectedPhotos: [PhotoAsset] = []

    // MARK: - Services
    private let library = PhotoLibraryManager.shared

    // MARK: - Persistence keys
    private let savedSpaceKey = "flicFinder.spaceSaved"
    private let cleanedKey = "flicFinder.photosCleaned"
    private let selectionKey = "flicFinder.selectedPhotoIDs"

    init() {
        spaceSaved = Int64(UserDefaults.standard.integer(forKey: savedSpaceKey))
        photosCleaned = UserDefaults.standard.integer(forKey: cleanedKey)
        // Selection itself is restored in onAppear (after permission is granted).
    }

    // MARK: - Lifecycle

    func onAppear() async {
        isLoading = true
        defer { isLoading = false }

        let granted = await library.requestAuthorization()
        guard granted else {
            permissionDenied = true
            return
        }
        await refreshStats()
        await restorePersistedSelection()
    }

    func refreshStats() async {
        let assets = await library.fetchAllPhotos()
        totalPhotos = assets.count
        totalLibrarySize = assets.reduce(0) { $0 + $1.fileSize }
    }

    func recordDeletion(freedBytes: Int64, deletedPhotoIDs: Set<String>) {
        spaceSaved += freedBytes
        photosCleaned += deletedPhotoIDs.count

        UserDefaults.standard.set(Int(spaceSaved), forKey: savedSpaceKey)
        UserDefaults.standard.set(photosCleaned, forKey: cleanedKey)

        // Some selected photos may have just been deleted — drop them.
        selectedPhotos.removeAll { deletedPhotoIDs.contains($0.id) }
        persistSelection()

        Task { await refreshStats() }
    }

    // MARK: - Selection Management

    func updateSelection(_ photos: [PhotoAsset]) {
        selectedPhotos = photos
        selectionErrorMessage = nil
        persistSelection()
    }

    @discardableResult
    func updateSelection(fromPickerItems items: [PhotosPickerItem]) async -> [PhotoAsset] {
        let photos = await convertPickerItems(items)
        selectedPhotos = photos

        if items.isEmpty || !photos.isEmpty {
            selectionErrorMessage = nil
        }

        persistSelection()
        return photos
    }

    func clearSelection() {
        selectedPhotos.removeAll()
        persistSelection()
    }

    private func persistSelection() {
        let ids = selectedPhotos.map { $0.id }
        UserDefaults.standard.set(ids, forKey: selectionKey)
    }

    /// Loads any saved selection IDs from disk and rehydrates them into PhotoAssets.
    /// Photos that no longer exist (deleted, access revoked) are silently dropped.
    private func restorePersistedSelection() async {
        guard let savedIDs = UserDefaults.standard.stringArray(forKey: selectionKey),
              !savedIDs.isEmpty else { return }

        let restored = await library.fetchPhotos(withLocalIdentifiers: savedIDs)

        selectedPhotos = restored
        // If anything was filtered out (deleted photos), update persistence
        // so we don't keep retrying stale IDs.
        if restored.count != savedIDs.count {
            persistSelection()
        }
    }

    var hasSelection: Bool { !selectedPhotos.isEmpty }

    /// Always reflects the user's selected count, never the total library count.
    var photoStatValue: String {
        "\(selectedPhotos.count)"
    }

    var photoStatLabel: String {
        "Selected"
    }

    // MARK: - PhotosPicker conversion

    func convertPickerItems(_ items: [PhotosPickerItem]) async -> [PhotoAsset] {
        let identifiers = items.compactMap(\.itemIdentifier)
        let photos = await library.fetchPhotos(withLocalIdentifiers: identifiers)

        if !items.isEmpty && photos.isEmpty {
            selectionErrorMessage = "FlicFinder could not read those selected photos from your library. Please try choosing them again."
        }

        return photos
    }

    // MARK: - Formatted Outputs

    var formattedSpaceSaved: String {
        ByteCountFormatter.string(fromByteCount: spaceSaved, countStyle: .file)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalLibrarySize, countStyle: .file)
    }
}
