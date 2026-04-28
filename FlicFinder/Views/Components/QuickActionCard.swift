//
//  QuickActionCard.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//


import SwiftUI

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(action.color.opacity(0.12))
                    .foregroundStyle(action.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 2) {
                    Text(action.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(action.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
