import SwiftUI

/// A floating translation bubble that covers the original manga speech bubble.
///
/// When `targetSize` is supplied (live/static scan mode), the bubble sizes itself
/// to exactly match the detected text region, replacing the original text.
/// When `targetSize` is nil (standalone/history mode), it uses a compact pill style.
struct TranslationBubble: View {

    let result: TranslationResult
    /// The bounding box size mapped to screen points.
    /// Pass this from TranslationOverlayView so the bubble covers the original text.
    var targetSize: CGSize? = nil
    let onDismiss: () -> Void

    @State private var isExpanded: Bool = false

    // Computed font size: scales with available height when targetSize is provided.
    private var translatedFontSize: CGFloat {
        guard let size = targetSize else { return 14 }
        // Fill roughly 60% of the target height, capped between 11 and 18 pt.
        return min(max(size.height * 0.28, 11), 18)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── Background — solid white so original Korean text is hidden ──
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

            // ── Content ─────────────────────────────────────────────────────
            VStack(alignment: .center, spacing: 2) {
                // Original text (expanded only)
                if isExpanded {
                    Text(result.originalText)
                        .font(.system(size: max(translatedFontSize - 2, 9)))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Translated text (always visible)
                Text(result.translatedText)
                    .font(.system(size: translatedFontSize, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(isExpanded ? 6 : 4)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Mode indicator dot (top-left) ───────────────────────────────
            Circle()
                .fill(result.translationMode.indicatorColor)
                .frame(width: 6, height: 6)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // ── Dismiss button (top-right) ──────────────────────────────────
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(3)
        }
        // Size to match the detected speech bubble when targetSize is provided
        .frame(
            width:  targetSize.map { max($0.width,  80) },
            height: targetSize.map { max($0.height, 36) }
        )
        // Fallback compact size when used without targetSize
        .frame(minWidth: targetSize == nil ? 80 : nil,
               maxWidth: targetSize == nil ? 220 : nil)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal:   .scale(scale: 0.85).combined(with: .opacity)
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        // Standalone (no target size)
        TranslationBubble(result: TranslationResult.sampleData[0], onDismiss: {})

        // Sized to match a speech bubble
        TranslationBubble(
            result: TranslationResult.sampleData[1],
            targetSize: CGSize(width: 200, height: 70),
            onDismiss: {}
        )
    }
    .padding()
    .background(Color(.systemGray5))
}
#endif
