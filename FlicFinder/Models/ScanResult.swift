//
//  ScanResult.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Output from any analyzer — on-device Vision or Claude API.

import Foundation

struct ScanResult: Identifiable {
    let id = UUID()
    let photo: PhotoAsset
    let shouldDelete: Bool
    let confidence: Double // 0.0 to 1.0
    let reason: String // human-readable explanation
}
