// Created by: Matthew Ketas
// Last Edited: 4/2/2026
// LLMs Used: Claude Opus 4.6 Extended

// Home screen — observes HomeViewModel.
// All other types (QuickAction, QuickActionCard, StatItem, SmartSearchView) live in their own files. Do NOT redeclare them here.

import SwiftUI

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showSmartSearch = false
    @State private var selectedQuickAction: QuickAction? = nil

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
            StatItem(
                value: "\(viewModel.totalPhotos)",
                label: "Photos",
                icon: "photo.fill"
            )
            Divider().frame(height: 32)
            StatItem(
                value: "\(viewModel.photosCleaned)",
                label: "Cleaned",
                icon: "checkmark.circle.fill"
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
                        Text("Use AI to find photos by your description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
