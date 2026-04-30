//
//  PhotoLibraryManager.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// All interaction with the iOS Photos framework lives here.

import Foundation
import Photos
import UIKit

@MainActor
final class PhotoLibraryManager {

    static let shared = PhotoLibraryManager()
    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    var currentAuthStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Fetching

    func fetchAllPhotos() async -> [PhotoAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )

        let result = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PhotoAsset] = []

        result.enumerateObjects { asset, _, _ in
            assets.append(self.photoAsset(from: asset))
        }

        return assets
    }

    func fetchPhotos(withLocalIdentifiers identifiers: [String]) async -> [PhotoAsset] {
        guard !identifiers.isEmpty else { return [] }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetsByID: [String: PhotoAsset] = [:]

        result.enumerateObjects { asset, _, _ in
            assetsByID[asset.localIdentifier] = self.photoAsset(from: asset)
        }

        return identifiers.compactMap { assetsByID[$0] }
    }

    // MARK: - Thumbnail Loading

    func loadThumbnail(
        for asset: PHAsset,
        size: CGSize = CGSize(width: 200, height: 200)
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Loads a full-resolution image. Used by AI analysis where we need detail.
    func loadFullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Deletion

    @discardableResult
    func deletePhotos(_ assets: [PhotoAsset]) async throws -> Bool {
        let phAssets = assets.map { $0.phAsset }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(phAssets as NSArray)
        }
        return true
    }

    // MARK: - File Size Calculation

    private func fileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.reduce(Int64(0)) { total, resource in
            let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
            return total + size
        }
    }

    private func photoAsset(from asset: PHAsset) -> PhotoAsset {
        PhotoAsset(
            id: asset.localIdentifier,
            phAsset: asset,
            creationDate: asset.creationDate,
            fileSize: fileSize(for: asset)
        )
    }
}
