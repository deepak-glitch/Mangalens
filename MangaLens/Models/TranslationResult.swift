import SwiftUI

// MARK: - Enums

enum SourceLanguage: String, Codable, CaseIterable {
    case japanese = "japanese"
    case korean = "korean"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .auto: return "Auto"
        }
    }

    var flag: String {
        switch self {
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .auto: return "🌐"
        }
    }

    var badge: String {
        switch self {
        case .japanese: return "JP"
        case .korean: return "KR"
        case .auto: return "AUTO"
        }
    }
}

enum TranslationMode: String, Codable, CaseIterable {
    case ai = "ai"
    case standard = "standard"

    var displayName: String {
        switch self {
        case .ai: return "AI"
        case .standard: return "Standard"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .ai: return .blue
        case .standard: return .green
        }
    }
}

enum TranslationStyle: String, Codable, CaseIterable {
    case natural = "natural"
    case literal = "literal"
    case mangaTone = "mangaTone"

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .literal: return "Literal"
        case .mangaTone: return "Manga-tone"
        }
    }
}

// MARK: - TranslationResult

struct TranslationResult: Codable, Identifiable {
    var id: UUID
    var originalText: String
    var translatedText: String
    var sourceLanguage: SourceLanguage
    var boundingBox: CodableCGRect
    var timestamp: Date
    var translationMode: TranslationMode

    init(
        id: UUID = UUID(),
        originalText: String,
        translatedText: String,
        sourceLanguage: SourceLanguage,
        boundingBox: CGRect,
        timestamp: Date = Date(),
        translationMode: TranslationMode
    ) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.boundingBox = CodableCGRect(rect: boundingBox)
        self.timestamp = timestamp
        self.translationMode = translationMode
    }

    var cgBoundingBox: CGRect {
        boundingBox.rect
    }
}

// MARK: - CodableCGRect helper

struct CodableCGRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Sample Data

extension TranslationResult {
    static let sampleData: [TranslationResult] = [
        TranslationResult(
            originalText: "お前はもう死んでいる",
            translatedText: "You are already dead.",
            sourceLanguage: .japanese,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.08),
            translationMode: .ai
        ),
        TranslationResult(
            originalText: "나는 최강이다",
            translatedText: "I am the strongest.",
            sourceLanguage: .korean,
            boundingBox: CGRect(x: 0.5, y: 0.4, width: 0.35, height: 0.07),
            translationMode: .standard
        ),
        TranslationResult(
            originalText: "行くぞ！",
            translatedText: "Let's go!",
            sourceLanguage: .japanese,
            boundingBox: CGRect(x: 0.2, y: 0.6, width: 0.2, height: 0.06),
            translationMode: .ai
        )
    ]
}
