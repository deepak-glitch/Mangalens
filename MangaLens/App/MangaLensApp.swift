import SwiftUI

@main
struct MangaLensApp: App {

    @StateObject private var translationManager = TranslationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(translationManager)
        }
    }
}

// MARK: - Root Content View (TabView)

struct ContentView: View {

    @EnvironmentObject var manager: TranslationManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(TranslationManager())
}
#endif
