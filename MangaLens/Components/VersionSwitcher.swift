import SwiftUI

struct VersionSwitcher: View {

    @Binding var selection: TranslationMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TranslationMode.allCases, id: \.self) { mode in
                Button {
                    if selection != mode {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = mode
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(mode.indicatorColor)
                            .frame(width: 8, height: 8)
                            .opacity(selection == mode ? 1 : 0.4)

                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(selection == mode ? .semibold : .regular)
                            .foregroundColor(selection == mode ? .primary : .secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selection == mode ? Color(.systemBackground) : Color.clear)
                            .shadow(
                                color: selection == mode ? .black.opacity(0.1) : .clear,
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        VersionSwitcher(selection: .constant(.ai))
        VersionSwitcher(selection: .constant(.standard))
    }
    .padding()
}
#endif
