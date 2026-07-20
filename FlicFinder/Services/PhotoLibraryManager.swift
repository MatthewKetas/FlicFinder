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

nonisolated final class PhotoLibraryManager {

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

    @concurrent func fetchAllPhotos() async -> [PhotoAsset] {
        photos(from: PHAsset.fetchAssets(with: photoFetchOptions()))
    }

    @concurrent func fetchRecentPhotos(limit: Int) async -> [PhotoAsset] {
        photos(from: PHAsset.fetchAssets(with: photoFetchOptions(limit: limit)))
    }

    private func photos(from result: PHFetchResult<PHAsset>) -> [PhotoAsset] {
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assets.append(self.photoAsset(from: asset))
        }

        return assets
    }

    @concurrent func fetchPhotos(withLocalIdentifiers identifiers: [String]) async -> [PhotoAsset] {
        guard !identifiers.isEmpty else { return [] }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetsByID: [String: PhotoAsset] = [:]

        result.enumerateObjects { asset, _, _ in
            assetsByID[asset.localIdentifier] = self.photoAsset(from: asset)
        }

        return identifiers.compactMap { assetsByID[$0] }
    }

    private func photoFetchOptions(limit: Int = 0) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        options.fetchLimit = limit
        return options
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

    @concurrent func fetchFileSizes(for assets: [PhotoAsset]) async -> [String: Int64] {
        Dictionary(uniqueKeysWithValues: assets.map { photo in
            let bytes = PHAssetResource.assetResources(for: photo.phAsset)
                .reduce(Int64(0)) { total, resource in
                    total + (resource.value(forKey: "fileSize") as? Int64 ?? 0)
                }
            return (photo.id, bytes)
        })
    }

    private func photoAsset(from asset: PHAsset) -> PhotoAsset {
        PhotoAsset(
            id: asset.localIdentifier,
            phAsset: asset,
            creationDate: asset.creationDate
        )
    }
}
