//
//  StatItem.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//


import SwiftUI

struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}
