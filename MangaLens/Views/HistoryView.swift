import SwiftUI

struct HistoryView: View {

    @EnvironmentObject var manager: TranslationManager
    @State private var showClearConfirm = false
    @State private var selectedSession: ScanSession? = nil

    private var sortedHistory: [ScanSession] {
        manager.scanHistory.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if manager.scanHistory.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sortedHistory) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                HistoryRowView(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.forEach { idx in
                                manager.deleteSession(sortedHistory[idx])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !manager.scanHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(
                "Clear all scan history?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    manager.clearAllHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
                    .environmentObject(manager)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text("No history yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Your scan sessions will\nappear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History Row

private struct HistoryRowView: View {

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
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(session.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("\(session.translationCount) translation\(session.translationCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    LanguageBadge(language: session.dominantLanguage)
                    ModeBadge(mode: session.dominantMode)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {

    let session: ScanSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Image with overlay
                    if let image = session.sourceImage {
                        TranslationOverlayView(image: image, results: session.results)
                            .frame(height: 320)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }

                    Divider()

                    // Translation results list
                    LazyVStack(spacing: 0) {
                        ForEach(session.results) { result in
                            TranslationResultRow(result: result)
                            Divider()
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(session.formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Translation Result Row

private struct TranslationResultRow: View {

    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LanguageBadge(language: result.sourceLanguage)
                ModeBadge(mode: result.translationMode)
                Spacer()
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(result.originalText)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(result.translatedText)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HistoryView()
        .environmentObject({
            let m = TranslationManager()
            m.scanHistory = ScanSession.sampleData
            return m
        }())
}
#endif
