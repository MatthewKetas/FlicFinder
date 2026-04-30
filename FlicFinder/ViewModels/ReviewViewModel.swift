//
//  ReviewViewModel.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Owns selection state and the deletion flow for ReviewView.


import Foundation
import SwiftUI

@Observable
@MainActor
final class ReviewViewModel {

    // MARK: - State
    var results: [ScanResult]
    var selectedIDs: Set<UUID> = []
    var isDeleting: Bool = false
    var didCompleteDeletion: Bool = false
    var deletionError: String?

    // MARK: - Services
    private let library = PhotoLibraryManager.shared

    init(results: [ScanResult]) {
        self.results = results
        // Pre-select everything the analyzer flagged for deletion
        self.selectedIDs = Set(results.filter { $0.shouldDelete }.map { $0.id })
    }

    // MARK: - Selection

    func toggle(_ result: ScanResult) {
        if selectedIDs.contains(result.id) {
            selectedIDs.remove(result.id)
        } else {
            selectedIDs.insert(result.id)
        }
    }

    func selectAll() {
        selectedIDs = Set(results.map { $0.id })
    }

    func deselectAll() {
        selectedIDs.removeAll()
    }

    var selectedResults: [ScanResult] {
        results.filter { selectedIDs.contains($0.id) }
    }

    var totalSelectedSize: Int64 {
        selectedResults.reduce(0) { $0 + $1.photo.fileSize }
    }

    var formattedSelectedSize: String {
        ByteCountFormatter.string(
            fromByteCount: totalSelectedSize,
            countStyle: .file
        )
    }

    // MARK: - Deletion

    /// Returns the bytes freed and deleted IDs so the caller can update HomeViewModel.
    func confirmDeletion() async -> (bytesFreed: Int64, deletedPhotoIDs: Set<String>)? {
        let toDelete = selectedResults.map { $0.photo }
        guard !toDelete.isEmpty else { return nil }

        isDeleting = true
        defer { isDeleting = false }

        let bytesFreed = totalSelectedSize
        let deletedPhotoIDs = Set(toDelete.map(\.id))

        do {
            try await library.deletePhotos(toDelete)
            didCompleteDeletion = true
            return (bytesFreed, deletedPhotoIDs)
        } catch {
            deletionError = error.localizedDescription
            return nil
        }
    }
}
