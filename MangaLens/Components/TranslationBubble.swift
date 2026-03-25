import SwiftUI

struct TranslationBubble: View {

    let result: TranslationResult
    let onDismiss: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row: mode indicator dot + dismiss button
            HStack {
                Circle()
                    .fill(result.translationMode.indicatorColor)
                    .frame(width: 8, height: 8)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Original text (expanded only)
            if isExpanded {
                Text(result.originalText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Translated text (always visible)
            Text(result.translatedText)
                .font(.body)
                .fontWeight(isExpanded ? .bold : .regular)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? 5 : 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        )
        .frame(minWidth: 80, maxWidth: 220)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        TranslationBubble(result: TranslationResult.sampleData[0], onDismiss: {})
        TranslationBubble(result: TranslationResult.sampleData[1], onDismiss: {})
    }
    .padding()
    .background(Color(.systemGray6))
}
#endif
