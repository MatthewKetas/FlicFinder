// Created by: Matthew Ketas
// Last Edited: 4/28/2026
// LLMs Used: Claude Opus 4.7

// Home screen — observes HomeViewModel.

import SwiftUI
import PhotosUI
import Photos

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showSmartSearch = false
    @State private var selectedQuickAction: QuickAction? = nil

    // Photo picker state
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingPickerFromHome = false
    @State private var showPickerInfo = false

    private let accentPurple = Color(red: 0.45, green: 0.31, blue: 0.85)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    statsSection
                    quickActionsSection
                    smartSearchButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FlicFinder")
            .task {
                await viewModel.onAppear()
            }
            .sheet(item: $selectedQuickAction) { action in
                ScanView(action: action, homeViewModel: viewModel)
            }
            .sheet(isPresented: $showSmartSearch) {
                SmartSearchView(homeViewModel: viewModel)
            }
            .photosPicker(
                isPresented: $showingPickerFromHome,
                selection: $pickerItems,
                maxSelectionCount: 0,    // 0 = unlimited
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: pickerItems) { _, newItems in
                Task {
                    await viewModel.updateSelection(fromPickerItems: newItems)
                }
            }
            .alert("Choose your photos", isPresented: $showPickerInfo) {
                Button("Got it") {
                    showingPickerFromHome = true
                }
            } message: {
                Text("Pick the photos you'd like the AI smart search to analyze. Tap the photo count again any time to change your selection.")
            }
            .alert(
                "Photo selection failed",
                isPresented: Binding(
                    get: { viewModel.selectionErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.selectionErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.selectionErrorMessage ?? "")
            }
            .alert("Photo access required", isPresented: $viewModel.permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("FlicFinder needs photo library access to help you clean it up.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentPurple, .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 4)
            Text("Clean up your photo library")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            // Photos stat is a button that opens the picker
            Button {
                if viewModel.hasSelection {
                    showingPickerFromHome = true   // skip info dialog if already used
                } else {
                    showPickerInfo = true
                }
            } label: {
                StatItem(
                    value: viewModel.photoStatValue,
                    label: viewModel.photoStatLabel,
                    icon: viewModel.hasSelection
                        ? "checkmark.circle.fill"
                        : "photo.fill"
                )
            }
            .buttonStyle(.plain)

            Divider().frame(height: 32)
            StatItem(
                value: "\(viewModel.photosCleaned)",
                label: "Cleaned",
                icon: "checkmark.seal.fill"
            )
            Divider().frame(height: 32)
            StatItem(
                value: viewModel.formattedSpaceSaved,
                label: "Space Saved",
                icon: "externaldrive.fill"
            )
        }
        .padding(.vertical, 14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Quick cleanup", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(QuickAction.allCases) { action in
                    QuickActionCard(action: action) {
                        selectedQuickAction = action
                    }
                }
            }
        }
    }

    private var smartSearchButton: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("AI smart search", systemImage: "sparkle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Button {
                showSmartSearch = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "brain")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .background(accentPurple.opacity(0.12))
                        .foregroundStyle(accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Describe what to delete")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if viewModel.hasSelection {
                            Text("Within \(viewModel.selectedPhotos.count) selected photos")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        } else {
                            Text("Use AI to find photos by your description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ContentView()
}
