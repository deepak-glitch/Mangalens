import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var manager: TranslationManager
    @Environment(\.dismiss) private var dismiss

    // Claude settings
    @State private var claudeAPIKey: String = ""
    @State private var claudeTestStatus: TestStatus = .idle

    // Ollama settings
    @State private var ollamaURL: String = ""
    @State private var ollamaModel: String = ""
    @State private var ollamaTestStatus: TestStatus = .idle

    enum TestStatus {
        case idle, testing, success(String), failure(String)

        var label: String {
            switch self {
            case .idle: return "Test Connection"
            case .testing: return "Testing..."
            case .success(let msg): return "✓ \(msg)"
            case .failure(let msg): return "✗ \(msg)"
            }
        }

        var color: Color {
            switch self {
            case .idle: return .blue
            case .testing: return .secondary
            case .success: return .green
            case .failure: return .red
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Translation Section
                Section("Translation") {
                    Picker("Default Language", selection: $manager.sourceLanguage) {
                        ForEach(SourceLanguage.allCases, id: \.self) { lang in
                            Text("\(lang.flag) \(lang.displayName)").tag(lang)
                        }
                    }

                    Picker("Default Mode", selection: $manager.translationMode) {
                        ForEach(TranslationMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("Translation Style", selection: $manager.translationStyle) {
                        ForEach(TranslationStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }

                // MARK: Claude Section
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
                    Text("Requires an Anthropic API key. Get one at console.anthropic.com")
                }

                // MARK: Ollama Section
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Circle()
                            .fill(ollamaStatusColor)
                            .frame(width: 10, height: 10)
                        Text(ollamaStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TextField("Server URL", text: $ollamaURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: ollamaURL) { _, val in
                            UserDefaults.standard.set(val, forKey: "OllamaServerURL")
                            ollamaTestStatus = .idle
                            manager.syncOllamaSettings()
                        }

                    TextField("Model Name", text: $ollamaModel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: ollamaModel) { _, val in
                            UserDefaults.standard.set(val, forKey: "OllamaModel")
                            ollamaTestStatus = .idle
                            manager.syncOllamaSettings()
                        }

                    Button {
                        testOllama()
                    } label: {
                        HStack {
                            Text(ollamaTestStatus.label)
                                .foregroundColor(ollamaTestStatus.color)
                            Spacer()
                            if case .testing = ollamaTestStatus {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled({ if case .testing = ollamaTestStatus { return true }; return false }())
                } header: {
                    Text("Standard Mode (Ollama)")
                } footer: {
                    Text("Standard Mode requires Ollama running on a Mac/PC on the same network as your iPhone.")
                }

                // MARK: About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("About Standard Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Standard Mode uses Ollama with the qwen2.5 model running locally on your Mac or PC. Both devices must be on the same Wi-Fi network. Install Ollama at ollama.com and run: ollama pull qwen2.5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: loadSettings)
        }
    }

    // MARK: - Helpers

    private var ollamaStatusColor: Color {
        switch ollamaTestStatus {
        case .success: return .green
        case .failure: return .red
        default: return .gray
        }
    }

    private var ollamaStatusText: String {
        switch ollamaTestStatus {
        case .success: return "Connected"
        case .failure: return "Not Reachable"
        default: return "Unknown"
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        claudeAPIKey = defaults.string(forKey: "ClaudeAPIKey") ?? ""
        ollamaURL = defaults.string(forKey: "OllamaServerURL") ?? OllamaTranslationService.defaultServerURL
        ollamaModel = defaults.string(forKey: "OllamaModel") ?? OllamaTranslationService.defaultModel
    }

    private func testClaude() {
        claudeTestStatus = .testing
        Task {
            let result = await manager.testClaudeConnection()
            await MainActor.run {
                switch result {
                case .success(let translation):
                    claudeTestStatus = .success("Connected – \"\(translation)\"")
                case .failure(let error):
                    claudeTestStatus = .failure(error.errorDescription ?? "Unknown error")
                }
            }
        }
    }

    private func testOllama() {
        ollamaTestStatus = .testing
        Task {
            let reachable = await manager.checkOllamaConnection()
            await MainActor.run {
                ollamaTestStatus = reachable
                    ? .success("Ollama is reachable")
                    : .failure("Cannot connect to \(ollamaURL)")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(TranslationManager())
}
#endif
