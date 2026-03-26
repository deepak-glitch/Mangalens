import SwiftUI

struct LanguageToggle: View {

    @Binding var selection: SourceLanguage

    var body: some View {
        Picker("Language", selection: $selection) {
            ForEach(SourceLanguage.allCases, id: \.self) { lang in
                Text("\(lang.flag) \(lang.displayName)")
                    .tag(lang)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LanguageToggle(selection: .constant(.auto))
        .padding()
}
#endif
