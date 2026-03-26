import Vision
import UIKit

// MARK: - Errors

enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case visionError(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process the image for text detection."
        case .noTextFound:
            return "No Japanese or Korean text was detected in the image."
        case .visionError(let error):
            return "Text detection error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Detected Text Block

struct DetectedTextBlock {
    let detectedString: String
    let boundingBox: CGRect   // normalized (0–1), Vision coordinate system (origin bottom-left)
    let detectedLanguage: SourceLanguage
}

// MARK: - OCR Service

final class OCRService {

    // Unicode ranges for Japanese and Korean characters
    private static let japaneseRanges: [ClosedRange<Unicode.Scalar>] = [
        Unicode.Scalar(0x3000)!...Unicode.Scalar(0x9FFF)!,
        Unicode.Scalar(0xF900)!...Unicode.Scalar(0xFAFF)!
    ]

    private static let koreanRanges: [ClosedRange<Unicode.Scalar>] = [
        Unicode.Scalar(0xAC00)!...Unicode.Scalar(0xD7AF)!,
        Unicode.Scalar(0x1100)!...Unicode.Scalar(0x11FF)!
    ]

    // MARK: - Public API

    func detectText(in image: UIImage) async throws -> [DetectedTextBlock] {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.visionError(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let blocks: [DetectedTextBlock] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let text = candidate.string
                    guard let language = Self.detectLanguage(in: text) else { return nil }
                    return DetectedTextBlock(
                        detectedString: text,
                        boundingBox: observation.boundingBox,
                        detectedLanguage: language
                    )
                }

                if blocks.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: blocks)
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja", "ko", "zh-Hans"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionError(error))
            }
        }
    }

    // MARK: - Language Detection

    static func detectLanguage(in text: String) -> SourceLanguage? {
        var japaneseCount = 0
        var koreanCount = 0

        for scalar in text.unicodeScalars {
            if japaneseRanges.contains(where: { $0.contains(scalar) }) {
                japaneseCount += 1
            } else if koreanRanges.contains(where: { $0.contains(scalar) }) {
                koreanCount += 1
            }
        }

        let total = japaneseCount + koreanCount
        guard total > 0 else { return nil }

        return japaneseCount >= koreanCount ? .japanese : .korean
    }

    // MARK: - Coordinate Conversion

    /// Converts Vision's normalized bounding box (origin at bottom-left) to
    /// a rect in UIKit coordinates (origin at top-left) within `imageSize`.
    static func convertBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }
}
