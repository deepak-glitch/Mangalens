import SwiftUI

/// Live screen-recording translation view.
///
/// Flow:
///   1. User taps "Start Live Translation"
///   2. iOS shows the ReplayKit screen recording consent sheet
///   3. Once accepted, ScreenCaptureService starts delivering UIImage frames
///   4. Each frame goes through OCR → Claude → liveResults published
///   5. TranslationOverlayView renders English bubbles directly on speech bubbles
///   6. User taps "Stop" to end recording
struct LiveScanView: View {

    @EnvironmentObject var manager: TranslationManager

    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if manager.isLiveMode, let frame = manager.screenCapture.latestFrame {
                // ── Live frame + bubble overlay ───────────────────────────
                TranslationOverlayView(image: frame.image, results: manager.liveResults)
                    .ignoresSafeArea()
            } else {
                // ── Idle / no frame yet ───────────────────────────────────
                idlePlaceholder
            }

            // ── HUD overlay (always on top) ───────────────────────────────
            VStack {
                hudBar
                Spacer()
                if !manager.isLiveMode {
                    startButton
                        .padding(.bottom, 48)
                }
            }
        }
        .alert("Screen Recording", isPresented: $showPermissionAlert) {
            Button("OK") {}
        } message: {
            Text(permissionMessage)
        }
    }

    // MARK: - HUD Bar

    private var hudBar: some View {
        HStack(spacing: 12) {
            if manager.isLiveMode {
                // Pulsing red recording indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(Color.red.opacity(0.4), lineWidth: 4)
                    )

                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                Text("·")
                    .foregroundColor(.white.opacity(0.5))

                Text("\(manager.screenCapture.fps) fps")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))

                Text("·")
                    .foregroundColor(.white.opacity(0.5))

                Text("\(manager.liveResults.count) bubble\(manager.liveResults.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if manager.isLiveMode {
                Button {
                    Task { await manager.stopLiveMode() }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("Stop")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Idle Placeholder

    private var idlePlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.inset.filled.and.person.filled")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.4))

            Text("Live Translation")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("MangaLens will record your screen and translate\nKorean and Japanese speech bubbles in real-time.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if manager.isTranslating {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                do {
                    try await manager.startLiveMode()
                } catch let error as ScreenCaptureError {
                    permissionMessage = error.errorDescription ?? "Could not start screen recording."
                    showPermissionAlert = true
                } catch {
                    permissionMessage = error.localizedDescription
                    showPermissionAlert = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "record.circle")
                    .font(.title3)
                Text("Start Live Translation")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(Color.red)
            .clipShape(Capsule())
            .shadow(color: .red.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LiveScanView()
        .environmentObject(TranslationManager())
}
#endif
