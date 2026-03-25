import SwiftUI

struct HomeView: View {

    @EnvironmentObject var manager: TranslationManager
    @State private var showScan = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mode + Language Controls
                    VStack(spacing: 12) {
                        VersionSwitcher(selection: $manager.translationMode)
                        LanguageToggle(selection: $manager.sourceLanguage)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Scan Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showScan = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "viewfinder.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.blue)

                            Text("Scan Manga")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Camera or Screenshot")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Recent Scans
                    recentScansSection
                }
            }
            .navigationTitle("MangaLens")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .fullScreenCover(isPresented: $showScan) {
                ScanView()
                    .environmentObject(manager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(manager)
            }
            .alert("Error", isPresented: .constant(manager.errorMessage != nil)) {
                Button("OK") { manager.errorMessage = nil }
            } message: {
                Text(manager.errorMessage ?? "")
            }
        }
    }

    // MARK: - Recent Scans Section

    @ViewBuilder
    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Scans")
                    .font(.headline)
                    .padding(.horizontal)

                Spacer()
            }

            if manager.scanHistory.isEmpty {
                emptyState
            } else {
                let recent = Array(manager.scanHistory.prefix(5))
                VStack(spacing: 10) {
                    ForEach(recent) { session in
                        ScanSessionCard(session: session)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No scans yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Tap the Scan button to translate\nJapanese or Korean manga text")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Scan Session Card

private struct ScanSessionCard: View {

    let session: ScanSession

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let img = session.sourceImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray5))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(session.translationCount) translation\(session.translationCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Badges
            VStack(alignment: .trailing, spacing: 4) {
                LanguageBadge(language: session.dominantLanguage)
                ModeBadge(mode: session.dominantMode)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Shared Badges

struct LanguageBadge: View {
    let language: SourceLanguage
    var body: some View {
        Text(language.badge)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

struct ModeBadge: View {
    let mode: TranslationMode
    var body: some View {
        Text(mode.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(mode.indicatorColor.opacity(0.15))
            .foregroundColor(mode.indicatorColor)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HomeView()
        .environmentObject({
            let m = TranslationManager()
            m.scanHistory = ScanSession.sampleData
            return m
        }())
}
#endif
