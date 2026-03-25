import Foundation

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case rateLimited
    case apiError(String)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is missing. Please add it in Settings."
        case .rateLimited:
            return "Claude API rate limit reached. Please wait a moment and try again."
        case .apiError(let message):
            return "Claude API error: \(message)"
        case .decodingError:
            return "Failed to parse Claude API response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Models

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Decodable {
    let content: [ClaudeContentBlock]
}

private struct ClaudeContentBlock: Decodable {
    let type: String
    let text: String?
}

private struct ClaudeErrorResponse: Decodable {
    let error: ClaudeErrorDetail
}

private struct ClaudeErrorDetail: Decodable {
    let type: String
    let message: String
}

// MARK: - Claude Translation Service

final class ClaudeTranslationService {

    private let model = "claude-sonnet-4-20250514"
    private let baseURL = "https://api.anthropic.com/v1/messages"

    private let systemPrompt = """
        You are a manga/webtoon translation expert. Translate the given Japanese or Korean text \
        to English naturally, preserving the tone, emotion, and style typical of manga dialogue. \
        Keep translations concise and punchy as they will be displayed in speech bubbles. \
        Return ONLY the translated text, nothing else.
        """

    // MARK: - API Key

    private func loadAPIKey() throws -> String {
        // Check UserDefaults first (set from Settings)
        if let key = UserDefaults.standard.string(forKey: "ClaudeAPIKey"), !key.isEmpty {
            return key
        }
        // Fallback to Config.plist
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["ClaudeAPIKey"] as? String,
              !key.isEmpty else {
            throw ClaudeError.missingAPIKey
        }
        return key
    }

    // MARK: - Translation

    func translate(_ text: String, from language: SourceLanguage) async throws -> String {
        let apiKey = try loadAPIKey()

        let userMessage = "Translate this \(language.displayName) manga text to English:\n\(text)"

        let requestBody = ClaudeRequest(
            model: model,
            max_tokens: 256,
            system: systemPrompt,
            messages: [ClaudeMessage(role: "user", content: userMessage)]
        )

        guard let url = URL(string: baseURL) else {
            throw ClaudeError.apiError("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ClaudeError.networkError(error)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.decodingError
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw ClaudeError.rateLimited
        default:
            // Try to parse error message from body
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ClaudeError.apiError(errorResponse.error.message)
            }
            throw ClaudeError.apiError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            guard let textContent = decoded.content.first(where: { $0.type == "text" }),
                  let text = textContent.text else {
                throw ClaudeError.decodingError
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.decodingError
        }
    }

    // MARK: - Test Connection

    func testConnection() async -> Result<String, ClaudeError> {
        do {
            let result = try await translate("こんにちは", from: .japanese)
            return .success(result)
        } catch let error as ClaudeError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }
}
