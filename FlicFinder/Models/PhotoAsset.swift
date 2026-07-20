//
//  PhotoAsset.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// A lightweight wrapper around Apple's PHAsset.

import Foundation
import Photos
import UIKit

struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let phAsset: PHAsset
    let creationDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
}
