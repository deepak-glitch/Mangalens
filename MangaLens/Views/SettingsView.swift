import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var manager: TranslationManager
    @EnvironmentObject var auth: SupabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var claudeAPIKey: String = ""
    @State private var claudeTestStatus: TestStatus = .idle

    enum TestStatus {
        case idle, testing, success(String), failure(String)

        var label: String {
            switch self {
            case .idle:             return "Test Connection"
            case .testing:          return "Testing..."
            case .success(let m):   return "✓ \(m)"
            case .failure(let m):   return "✗ \(m)"
            }
        }

        var color: Color {
            switch self {
            case .idle:     return .blue
            case .testing:  return .secondary
            case .success:  return .green
            case .failure:  return .red
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Translation
                Section("Translation") {
                    Picker("Default Language", selection: $manager.sourceLanguage) {
                        ForEach(SourceLanguage.allCases, id: \.self) { lang in
                            Text("\(lang.flag) \(lang.displayName)").tag(lang)
                        }
                    }

                    Picker("Translation Style", selection: $manager.translationStyle) {
                        ForEach(TranslationStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }

                // MARK: AI Mode (Claude)
                Section {
                    SecureField("API Key", text: $claudeAPIKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: claudeAPIKey) { _, val in
                            UserDefaults.standard.set(val, forKey: "ClaudeAPIKey")
                            claudeTestStatus = .idle
                        }

                    Button {
                        testClaude()
                    } label: {
                        HStack {
                            Text(claudeTestStatus.label)
                                .foregroundColor(claudeTestStatus.color)
                            Spacer()
                            if case .testing = claudeTestStatus {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled({ if case .testing = claudeTestStatus { return true }; return false }())
                } header: {
                    Text("AI Mode (Claude)")
                } footer: {
                    Text("Get your API key at console.anthropic.com")
                }

                // MARK: Standard Mode — Coming Soon
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coming in Phase 2")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Local on-device translation with qwen2.5 via Ollama — no API key required.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Standard Mode (Ollama)")
                } footer: {
                    Text("Phase 2 will add fully offline translation running on your Mac or PC via Ollama on the same Wi-Fi network.")
                }

                // MARK: Account
                Section("Account") {
                    if let user = auth.currentUser {
                        HStack {
                            Label(user.email ?? "Signed in", systemImage: "person.circle.fill")
                            Spacer()
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadSettings() }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func loadSettings() {
        claudeAPIKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey") ?? ""
    }

    private func testClaude() {
        claudeTestStatus = .testing
        Task {
            let result = await manager.testClaudeConnection()
            claudeTestStatus = switch result {
            case .success(let t): .success("Connected – \"\(t)\"")
            case .failure(let e): .failure(e.errorDescription ?? "Unknown error")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(TranslationManager())
        .environmentObject(SupabaseService())
}
#endif
