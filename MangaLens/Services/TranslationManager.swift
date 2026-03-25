import SwiftUI
import UIKit

@MainActor
final class TranslationManager: ObservableObject {

    // MARK: - Published State

    @Published var translationMode: TranslationMode = .standard
    @Published var sourceLanguage: SourceLanguage = .auto
    @Published var isTranslating: Bool = false
    @Published var currentResults: [TranslationResult] = []
    @Published var scanHistory: [ScanSession] = []
    @Published var errorMessage: String? = nil
    @Published var translationStyle: TranslationStyle = .mangaTone

    // MARK: - Services

    private let ocrService = OCRService()
    private let claudeService = ClaudeTranslationService()
    private var ollamaService = OllamaTranslationService()

    // MARK: - Init

    init() {
        loadHistory()
        syncOllamaSettings()
    }

    // MARK: - Main Processing

    func processImage(_ image: UIImage) async {
        isTranslating = true
        errorMessage = nil
        currentResults = []

        defer { isTranslating = false }

        // 1. OCR
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

        // 2. Translate each block
        var results: [TranslationResult] = []
        var encounteredError: String? = nil

        for block in blocks {
            let lang: SourceLanguage = sourceLanguage == .auto ? block.detectedLanguage : sourceLanguage

            do {
                let translated: String
                switch translationMode {
                case .ai:
                    translated = try await claudeService.translate(block.detectedString, from: lang)
                case .standard:
                    syncOllamaSettings()
                    translated = try await ollamaService.translate(block.detectedString, from: lang)
                }

                let result = TranslationResult(
                    originalText: block.detectedString,
                    translatedText: translated,
                    sourceLanguage: lang,
                    boundingBox: block.boundingBox,
                    translationMode: translationMode
                )
                results.append(result)

            } catch {
                // Record first error but continue processing remaining blocks
                if encounteredError == nil {
                    encounteredError = error.localizedDescription
                }
            }
        }

        currentResults = results

        // 3. Save session if we got results
        if !results.isEmpty {
            let session = ScanSession(
                sourceImage: image,
                results: results,
                language: sourceLanguage
            )
            scanHistory.insert(session, at: 0)
            saveHistory()
        }

        if results.isEmpty, let err = encounteredError {
            errorMessage = err
        } else if let err = encounteredError {
            // Partial failure — surface warning
            errorMessage = "Some translations failed: \(err)"
        }

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - History Management

    func deleteSession(_ session: ScanSession) {
        scanHistory.removeAll { $0.id == session.id }
        saveHistory()
    }

    func clearAllHistory() {
        scanHistory.removeAll()
        saveHistory()
    }

    // MARK: - Ollama Settings Sync

    func syncOllamaSettings() {
        ollamaService = OllamaTranslationService()
    }

    func checkOllamaConnection() async -> Bool {
        syncOllamaSettings()
        return await ollamaService.checkConnection()
    }

    func testClaudeConnection() async -> Result<String, ClaudeError> {
        return await claudeService.testConnection()
    }

    // MARK: - Persistence

    private let historyKey = "MangaLens_ScanHistory"

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(scanHistory)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            scanHistory = try JSONDecoder().decode([ScanSession].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}
