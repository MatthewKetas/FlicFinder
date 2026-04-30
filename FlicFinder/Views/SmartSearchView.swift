//
//  SmartSearchView.swift
//  FlicFinder
//

import SwiftUI
import PhotosUI
import Photos

struct SmartSearchView: View {
    let homeViewModel: HomeViewModel

    @State private var viewModel = SmartSearchViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showReducePicker = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    private let examples = [
        "Blurry photos of food",
        "Screenshots of texts",
        "Photos of the ground",
        "Unflattering selfies"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Analyzing photos with AI...")
                    Spacer()
                } else if !viewModel.results.isEmpty {
                    ReviewView(
                        results: viewModel.results,
                        homeViewModel: homeViewModel
                    )
                } else {
                    examplesSection
                    Spacer()
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    inputBar
                }
            }
            .navigationTitle("Smart Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInputFocused = true
                }
            }
            .alert(
                "Choose fewer photos",
                isPresented: Binding(
                    get: { viewModel.photoLimitPromptMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.photoLimitPromptMessage = nil
                        }
                    }
                )
            ) {
                Button("Select Photos") {
                    viewModel.photoLimitPromptMessage = nil
                    showReducePicker = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.photoLimitPromptMessage ?? "")
            }
            .photosPicker(
                isPresented: $showReducePicker,
                selection: $pickerItems,
                maxSelectionCount: smartSearchPhotoSelectionLimit,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: pickerItems) { _, newItems in
                Task {
                    let photos = await homeViewModel.updateSelection(
                        fromPickerItems: newItems
                    )
                    // Auto-retry the search with the reduced selection
                    await viewModel.submit(selectedPhotos: photos)
                }
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try something like:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            viewModel.prompt = example
                            isInputFocused = true
                        } label: {
                            Text(example)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.purple.opacity(0.1))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Describe photos to find...", text: $viewModel.prompt)
                .focused($isInputFocused)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await viewModel.submit(
                            selectedPhotos: homeViewModel.selectedPhotos
                        )
                    }
                }

            if !viewModel.prompt.isEmpty {
                Button {
                    Task {
                        await viewModel.submit(
                            selectedPhotos: homeViewModel.selectedPhotos
                        )
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: viewModel.prompt.isEmpty)
    }
}
