import UIKit

struct ScanSession: Codable, Identifiable {
    var id: UUID
    var date: Date
    var sourceImageData: Data?
    var results: [TranslationResult]
    var language: SourceLanguage

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        sourceImage: UIImage? = nil,
        results: [TranslationResult] = [],
        language: SourceLanguage = .auto
    ) {
        self.id = id
        self.date = date
        self.sourceImageData = sourceImage?.jpegData(compressionQuality: 0.7)
        self.results = results
        self.language = language
    }

    var sourceImage: UIImage? {
        guard let data = sourceImageData else { return nil }
        return UIImage(data: data)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    var translationCount: Int {
        results.count
    }

    var dominantLanguage: SourceLanguage {
        if language != .auto { return language }
        let jpCount = results.filter { $0.sourceLanguage == .japanese }.count
        let krCount = results.filter { $0.sourceLanguage == .korean }.count
        if jpCount >= krCount { return .japanese }
        return .korean
    }

    var dominantMode: TranslationMode {
        let aiCount = results.filter { $0.translationMode == .ai }.count
        let stdCount = results.filter { $0.translationMode == .standard }.count
        return aiCount >= stdCount ? .ai : .standard
    }
}

// MARK: - Sample Data

extension ScanSession {
    static let sampleData: [ScanSession] = [
        ScanSession(
            date: Date().addingTimeInterval(-3600),
            results: Array(TranslationResult.sampleData.prefix(2)),
            language: .japanese
        ),
        ScanSession(
            date: Date().addingTimeInterval(-86400),
            results: [TranslationResult.sampleData[1]],
            language: .korean
        ),
        ScanSession(
            date: Date().addingTimeInterval(-172800),
            results: TranslationResult.sampleData,
            language: .auto
        )
    ]
}
