//
//  ScanView.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// The sheet that shows when the user taps a quick action.
// Runs the scan, shows progress, then transitions to ReviewView.

import SwiftUI

struct ScanView: View {
    let action: QuickAction
    let homeViewModel: HomeViewModel

    @State private var viewModel = ScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isScanning {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)

                    Text("Scanning for \(action.title.lowercased())...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else if viewModel.results.isEmpty {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Nothing to clean up!")
                        .font(.headline)
                } else {
                    ReviewView(
                        results: viewModel.results,
                        homeViewModel: homeViewModel
                    )
                }
            }
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.runQuickAction(
                    action,
                    selectedPhotos: homeViewModel.selectedPhotos
                )
            }
        }
    }
}
