import SwiftUI

@main
struct MangaLensApp: App {

    @StateObject private var translationManager = TranslationManager()
    @StateObject private var auth = SupabaseService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(translationManager)
                .environmentObject(auth)
        }
    }
}

// MARK: - Root View (auth gate)

/// Shows LoginView when the user is not authenticated,
/// ContentView (TabView) when they are.
struct RootView: View {

    @EnvironmentObject var auth: SupabaseService

    var body: some View {
        if auth.isLoggedIn {
            ContentView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Content View (main TabView)

struct ContentView: View {

    @EnvironmentObject var manager: TranslationManager
    @EnvironmentObject var auth: SupabaseService

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    RootView()
        .environmentObject(TranslationManager())
        .environmentObject(SupabaseService())
}
#endif
