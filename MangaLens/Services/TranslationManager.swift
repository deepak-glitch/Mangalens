import SwiftUI
import Combine

@MainActor
final class TranslationManager: ObservableObject {

    // MARK: - Published State

    @Published var translationMode: TranslationMode = .ai
    @Published var sourceLanguage: SourceLanguage = .auto
    @Published var isTranslating: Bool = false
    @Published var currentResults: [TranslationResult] = []
    @Published var liveResults: [TranslationResult] = []
    @Published var scanHistory: [ScanSession] = []
    @Published var errorMessage: String? = nil
    @Published var translationStyle: TranslationStyle = .mangaTone
    @Published var isLiveMode: Bool = false

    // MARK: - Services

    private let ocrService = OCRService()
    private let claudeService = ClaudeTranslationService()
    let screenCapture = ScreenCaptureService()

    private var liveCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        loadHistory()
    }

    // MARK: - Static Image Processing

    func processImage(_ image: UIImage) async {
        isTranslating = true
        errorMessage = nil
        currentResults = []

        defer { isTranslating = false }

        let blocks: [DetectedTextBlock]
        do {
            blocks = try await ocrService.detectText(in: image)
        } catch let error as OCRError {
            errorMessage = error.errorDescription
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        var results: [TranslationResult] = []
        var firstError: String? = nil

        for block in blocks {
            let lang: SourceLanguage = sourceLanguage == .auto ? block.detectedLanguage : sourceLanguage
            do {
                let translated = try await translateBlock(block.detectedString, language: lang)
                results.append(TranslationResult(
                    originalText: block.detectedString,
                    translatedText: translated,
                    sourceLanguage: lang,
                    boundingBox: block.boundingBox,
                    translationMode: translationMode
                ))
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }

        currentResults = results

        if !results.isEmpty {
            let session = ScanSession(sourceImage: image, results: results, language: sourceLanguage)
            scanHistory.insert(session, at: 0)
            saveHistory()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if results.isEmpty, let err = firstError { errorMessage = err }
    }

    // MARK: - Live Mode

    func startLiveMode() async throws {
        liveResults = []
        try await screenCapture.startCapture()
        isLiveMode = true

        // Observe every new frame published by ScreenCaptureService
        liveCancellable = screenCapture.$latestFrame
            .compactMap { $0 }
            .sink { [weak self] frame in
                guard let self else { return }
                Task { await self.processLiveFrame(frame) }
            }
    }

    func stopLiveMode() async {
        liveCancellable?.cancel()
        liveCancellable = nil
        await screenCapture.stopCapture()
        isLiveMode = false
        liveResults = []
    }

    private func processLiveFrame(_ frame: CapturedFrame) async {
        guard frame.textBlocks.isEmpty == false else {
            liveResults = []
            return
        }

        var results: [TranslationResult] = []
        for block in frame.textBlocks {
            let lang: SourceLanguage = sourceLanguage == .auto ? block.detectedLanguage : sourceLanguage
            do {
                let translated = try await translateBlock(block.detectedString, language: lang)
                results.append(TranslationResult(
                    originalText: block.detectedString,
                    translatedText: translated,
                    sourceLanguage: lang,
                    boundingBox: block.boundingBox,
                    translationMode: translationMode
                ))
            } catch {
                // Silently skip blocks that fail in live mode to avoid alert spam
            }
        }

        liveResults = results
        if !results.isEmpty {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    // MARK: - Translation Dispatch

    private func translateBlock(_ text: String, language: SourceLanguage) async throws -> String {
        switch translationMode {
        case .ai:
            return try await claudeService.translate(text, from: language)
        case .standard:
            // Standard mode (Ollama) is Phase 2 — not yet implemented
            throw TranslationManagerError.standardModeUnavailable
        }
    }

    // MARK: - History

    func deleteSession(_ session: ScanSession) {
        scanHistory.removeAll { $0.id == session.id }
        saveHistory()
    }

    func clearAllHistory() {
        scanHistory.removeAll()
        saveHistory()
    }

    // MARK: - Connection Tests

    func testClaudeConnection() async -> Result<String, ClaudeError> {
        await claudeService.testConnection()
    }

    // MARK: - Persistence

    private let historyKey = "MangaLens_ScanHistory"

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(scanHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([ScanSession].self, from: data) else { return }
        scanHistory = decoded
    }
}

// MARK: - Errors

enum TranslationManagerError: LocalizedError {
    case standardModeUnavailable

    var errorDescription: String? {
        switch self {
        case .standardModeUnavailable:
            return "Standard Mode (Ollama) is coming in Phase 2. Please use AI Mode."
        }
    }
}
