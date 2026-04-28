//
//  QuickAction.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// The four built-in cleanup actions on the home screen.


import SwiftUI

enum QuickAction: String, CaseIterable, Identifiable {
    case blurry
    case screenshots
    case duplicates
    case oldPhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blurry: return "Blurry Photos"
        case .screenshots: return "Screenshots"
        case .duplicates: return "Near-Duplicates"
        case .oldPhotos: return "Old Photos"
        }
    }

    var subtitle: String {
        switch self {
        case .blurry: return "Find out-of-focus shots"
        case .screenshots: return "Detect screen captures"
        case .duplicates: return "Spot similar photos"
        case .oldPhotos: return "Surface forgotten photos"
        }
    }

    var icon: String {
        switch self {
        case .blurry: return "camera.metering.none"
        case .screenshots: return "rectangle.on.rectangle"
        case .duplicates: return "square.on.square"
        case .oldPhotos: return "calendar.badge.clock"
        }
    }

    var color: Color {
        switch self {
        case .blurry: return .orange
        case .screenshots: return .blue
        case .duplicates: return .green
        case .oldPhotos: return .red
        }
    }
}
