//
//  ReviewView.swift
//  FlicFinder
//
//  Created by Matthew Ketas on 4/27/26.
//

// Review screen — user picks which flagged photos to actually delete


import SwiftUI

struct ReviewView: View {
    @State private var viewModel: ReviewViewModel
    let homeViewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    init(results: [ScanResult], homeViewModel: HomeViewModel) {
        _viewModel = State(initialValue: ReviewViewModel(results: results))
        self.homeViewModel = homeViewModel
    }

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Top action bar
            HStack {
                Button(viewModel.selectedIDs.count == viewModel.results.count
                       ? "Deselect All"
                       : "Select All") {
                    if viewModel.selectedIDs.count == viewModel.results.count {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                }
                Spacer()
                Text("\(viewModel.selectedIDs.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            // Grid of flagged photos
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(viewModel.results) { result in
                        ResultThumbnail(
                            result: result,
                            isSelected: viewModel.selectedIDs.contains(result.id)
                        )
                        .onTapGesture {
                            viewModel.toggle(result)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Delete button
            VStack(spacing: 6) {
                Text(
                    viewModel.hasLoadedSizes
                        ? "Frees \(viewModel.formattedSelectedSize)"
                        : "Calculating space..."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await performDeletion() }
                } label: {
                    Text("Delete \(viewModel.selectedIDs.count) photos")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.selectedIDs.isEmpty ? .gray : .red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(
                    viewModel.selectedIDs.isEmpty
                        || viewModel.isDeleting
                        || viewModel.isLoadingSizes
                )
            }
            .padding()
        }
        .task {
            await viewModel.loadFileSizes()
        }
    }

    private func performDeletion() async {
        guard let summary = await viewModel.confirmDeletion() else { return }
        homeViewModel.recordDeletion(
            freedBytes: summary.bytesFreed,
            deletedPhotoIDs: summary.deletedPhotoIDs
        )
        dismiss()
    }
}

// MARK: - Thumbnail

struct ResultThumbnail: View {
    let result: ScanResult
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
            }

            // Selection overlay
            if isSelected {
                Color.black.opacity(0.3)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .red)
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            thumbnail = await PhotoLibraryManager.shared.loadThumbnail(
                for: result.photo.phAsset
            )
        }
    }
}
