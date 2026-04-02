// Created by: Matthew Ketas
// Last Edited: 4/2/2026
// LLMs Used: Claude Opus 4.6 Extended

import SwiftUI

// MARK: - Main App View

struct ContentView: View {
    @State private var showSmartSearch = false
    @State private var selectedQuickAction: QuickAction? = nil

    private let accentPurple = Color(red: 0.45, green: 0.31, blue: 0.85)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    statsSection       // NEW: shows photo library stats
                    quickActionsSection
                    smartSearchButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FlicFinder")
            .sheet(item: $selectedQuickAction) { action in
                ResultsPlaceholderView(title: action.title)
            }
            .sheet(isPresented: $showSmartSearch) {
                SmartSearchView()
            }
        }
    }

    // MARK: - Header
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

    // MARK: - Stats Bar
    // DESIGN LESSON: A horizontal stats bar gives the app a "dashboard" feel.
    // Even with placeholder data, it makes the UI look more professional.
    // We'll wire these to real photo counts in Phase 2.
    private var statsSection: some View {
        HStack(spacing: 0) {
            StatItem(value: "—", label: "Photos Scanned", icon: "photo.fill")
            Divider().frame(height: 32)
            StatItem(value: "—", label: "Photos Cleaned", icon: "checkmark.circle.fill")
            Divider().frame(height: 32)
            StatItem(value: "—", label: "Storage Saved", icon: "externaldrive.fill")
        }
        .padding(.vertical, 14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Quick Actions Grid
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

    // MARK: - Smart Search Button
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
                            .foregroundStyle(.primary) // explicit so it doesn't
                                                       // inherit button styling
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


// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Quick Action Model

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

    var icon: String {
        switch self {
        case .blurry: return "camera.metering.none"
        case .screenshots: return "square.on.square.fill"
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

    var subtitle: String {
        switch self {
        case .blurry: return "Find out-of-focus shots"
        case .screenshots: return "Detect screen captures"
        case .duplicates: return "Spot similar photos"
        case .oldPhotos: return "Surface forgotten photos"
        }
    }
}


// MARK: - Quick Action Card

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


// MARK: - Smart Search View

struct SmartSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Try something like:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([
                                "Blurry photos of food",
                                "Screenshots of texts",
                                "Photos of the ground",
                                "Unflattering selfies"
                            ], id: \.self) { example in
                                Button {
                                    prompt = example
                                    isInputFocused = true
                                } label: {
                                    Text(example)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Color.purple.opacity(0.1)
                                        )
                                        .foregroundStyle(.purple)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Describe photos to find...", text: $prompt)
                        .focused($isInputFocused)
                        .submitLabel(.search) // Changes keyboard "return" to "Search"
                        .onSubmit {
                            guard !prompt.isEmpty else { return }
                            print("Searching for: \(prompt)")
                        }

                    if !prompt.isEmpty {
                        Button {
                            // TODO: Phase 4 — send to Claude API
                            print("Searching for: \(prompt)")
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
                .animation(.easeInOut(duration: 0.2), value: prompt.isEmpty)
            }
            .navigationTitle("Smart Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Auto-focus the input when the sheet opens
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInputFocused = true
                }
            }
        }
    }
}


// MARK: - Placeholder Results View

struct ResultsPlaceholderView: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 8)

                Text("Scanning for \(title.lowercased())...")
                    .font(.headline)
                Text("We'll wire this up in Phase 3!")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    ContentView()
}
