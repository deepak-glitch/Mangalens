import Foundation

// MARK: - Auth Models

struct SupabaseUser: Codable {
    let id: String
    let email: String?
}

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SupabaseAuthError: Decodable {
    let error: String?
    let error_description: String?
    let msg: String?         // Supabase v2 uses "msg"
    let message: String?     // fallback

    var displayMessage: String {
        error_description ?? msg ?? message ?? error ?? "Authentication failed."
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case missingConfiguration
    case invalidCredentials(String)
    case networkError(Error)
    case decodingError
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase URL or API key is not configured. Add them to Config.plist."
        case .invalidCredentials(let msg):
            return msg
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .decodingError:
            return "Unexpected response from server."
        case .notLoggedIn:
            return "You are not logged in."
        }
    }
}

// MARK: - Supabase Service

/// REST-only Supabase Auth wrapper — no SDK required.
/// Endpoints used:
///   POST /auth/v1/signup          — create account
///   POST /auth/v1/token           — sign in (grant_type=password)
///   POST /auth/v1/logout          — sign out
///   GET  /auth/v1/user            — fetch current user
///
@MainActor
final class SupabaseService: ObservableObject {

    // MARK: - Published

    @Published var currentUser: SupabaseUser? = nil
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Config

    private var supabaseURL: String {
        loadConfig("SupabaseURL") ?? ""
    }
    private var anonKey: String {
        loadConfig("SupabaseAnonKey") ?? ""
    }

    // MARK: - Persistent Session

    private let sessionKey = "MangaLens_SupabaseSession"

    private var session: SupabaseSession? {
        get {
            guard let data = UserDefaults.standard.data(forKey: sessionKey),
                  let s = try? JSONDecoder().decode(SupabaseSession.self, from: data) else { return nil }
            return s
        }
        set {
            if let s = newValue, let data = try? JSONEncoder().encode(s) {
                UserDefaults.standard.set(data, forKey: sessionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sessionKey)
            }
        }
    }

    // MARK: - Init

    init() {
        restoreSession()
    }

    func restoreSession() {
        if let s = session {
            currentUser = s.user
            isLoggedIn = true
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard !supabaseURL.isEmpty, !anonKey.isEmpty else {
            throw SupabaseError.missingConfiguration
        }

        let body: [String: String] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/signup", body: body, token: nil)

        // Supabase signup returns a session if email confirmation is disabled,
        // otherwise it returns a user object without a session.
        // We attempt to decode as session first, then as user-only.
        if let s = try? JSONDecoder().decode(SupabaseSession.self, from: data),
           !s.accessToken.isEmpty {
            session = s
            currentUser = s.user
            isLoggedIn = true
        } else {
            // Email confirmation required — just tell user to check email
            // (we don't auto-login until they confirm)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard !supabaseURL.isEmpty, !anonKey.isEmpty else {
            throw SupabaseError.missingConfiguration
        }

        let body: [String: String] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/token?grant_type=password", body: body, token: nil)

        do {
            let s = try JSONDecoder().decode(SupabaseSession.self, from: data)
            session = s
            currentUser = s.user
            isLoggedIn = true
        } catch {
            // Try to decode an error response
            if let authError = try? JSONDecoder().decode(SupabaseAuthError.self, from: data) {
                throw SupabaseError.invalidCredentials(authError.displayMessage)
            }
            throw SupabaseError.decodingError
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        if let token = session?.accessToken {
            _ = try? await post(path: "/auth/v1/logout", body: [:], token: token)
        }

        session = nil
        currentUser = nil
        isLoggedIn = false
    }

    // MARK: - HTTP Helper

    @discardableResult
    private func post(path: String, body: [String: String], token: String?) async throws -> Data {
        guard let url = URL(string: supabaseURL + path) else {
            throw SupabaseError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        } catch let e as SupabaseError {
            throw e
        } catch {
            throw SupabaseError.networkError(error)
        }
    }

    // MARK: - Config loader

    private func loadConfig(_ key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict[key] as? String,
              !value.isEmpty else { return nil }
        return value
    }
}
