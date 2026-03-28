import ReplayKit
import Vision
import UIKit

// MARK: - Screen Capture Errors

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case alreadyRecording
    case notRecording
    case frameConversionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission was denied. Go to Settings → Privacy → Screen Recording to enable MangaLens."
        case .alreadyRecording:
            return "Screen recording is already active."
        case .notRecording:
            return "Screen recording is not active."
        case .frameConversionFailed:
            return "Could not read a frame from the screen."
        }
    }
}

// MARK: - Captured Frame

/// One processed frame from the screen with OCR-detected text blocks.
struct CapturedFrame {
    let image: UIImage
    let textBlocks: [DetectedTextBlock]
    let timestamp: Date
}

// MARK: - Screen Capture Service

/// Captures live screen frames via ReplayKit, converts each frame to UIImage,
/// then hands it to OCRService for Japanese/Korean text detection.
///
/// Pipeline per frame:
///   CMSampleBuffer → CVPixelBuffer → CIImage → CGImage → UIImage → OCR
///
/// Every frame that passes the throttle is processed — no deduplication,
/// because the same text may legitimately appear on different manga pages.
///
@MainActor
final class ScreenCaptureService: ObservableObject {

    // MARK: - Published State

    @Published var isCapturing: Bool = false
    @Published var latestFrame: CapturedFrame? = nil
    @Published var errorMessage: String? = nil
    @Published var fps: Int = 0

    // MARK: - Private

    private let recorder = RPScreenRecorder.shared()
    private let ocrService = OCRService()

    /// Minimum time between OCR calls. 0.8 s → max ~1.25 calls/sec.
    /// Keeps CPU/GPU load reasonable without feeling laggy.
    private var lastProcessedAt: Date = .distantPast
    private let minimumProcessingInterval: TimeInterval = 0.8

    private var frameCount: Int = 0
    private var fpsTimer: Timer?

    /// Reused CIContext — creating one per frame is expensive.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Start

    func startCapture() async throws {
        guard recorder.isAvailable else { throw ScreenCaptureError.permissionDenied }
        guard !recorder.isRecording else { throw ScreenCaptureError.alreadyRecording }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // ReplayKit calls this handler on a background serial queue for every frame.
            recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
                if let error {
                    Task { @MainActor [weak self] in
                        self?.errorMessage = error.localizedDescription
                    }
                    return
                }
                guard bufferType == .video else { return }
                self?.handleFrame(sampleBuffer)

            }, completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        isCapturing = true
        startFPSCounter()
    }

    // MARK: - Stop

    func stopCapture() async {
        guard recorder.isRecording else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            recorder.stopCapture { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.isCapturing = false
                    self?.latestFrame = nil
                    self?.stopFPSCounter()
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Frame Handler (called on ReplayKit background thread)

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessedAt) >= minimumProcessingInterval else { return }
        lastProcessedAt = now

        // CMSampleBuffer   – ReplayKit's container for a single video frame.
        // CVPixelBuffer    – the raw BGRA pixel data inside the sample buffer.
        // CIImage          – Core Image representation; GPU-accelerated processing.
        // CGImage          – Core Graphics bitmap; required by Vision and UIKit.
        // UIImage          – what the rest of the app works with.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runOCR(on: uiImage, capturedAt: now)
        }
    }

    // MARK: - OCR

    private func runOCR(on image: UIImage, capturedAt timestamp: Date) async {
        do {
            let blocks = try await ocrService.detectText(in: image)
            let frame = CapturedFrame(image: image, textBlocks: blocks, timestamp: timestamp)
            await MainActor.run {
                self.frameCount += 1
                self.latestFrame = frame
            }
        } catch OCRError.noTextFound {
            // No JP/KR text in this frame — clear live results so stale bubbles disappear.
            await MainActor.run {
                self.latestFrame = CapturedFrame(image: image, textBlocks: [], timestamp: timestamp)
                self.frameCount += 1
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - FPS Counter

    private func startFPSCounter() {
        frameCount = 0
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.fps = self.frameCount
                self.frameCount = 0
            }
        }
    }

    private func stopFPSCounter() {
        fpsTimer?.invalidate()
        fpsTimer = nil
        fps = 0
        frameCount = 0
    }
}
