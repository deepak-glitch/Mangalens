import Foundation

// MARK: - Errors

enum OllamaError: LocalizedError {
    case unreachable
    case timeout
    case decodingError
    case networkError(Error)
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .unreachable:
            return "Cannot connect to Ollama. Make sure Ollama is running on your Mac/PC and this device is on the same network."
        case .timeout:
            return "Ollama request timed out. The server may be overloaded or the model is loading."
        case .decodingError:
            return "Failed to parse Ollama response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .modelNotFound(let model):
            return "Model '\(model)' not found on Ollama server. Run 'ollama pull \(model)' to install it."
        }
    }
}

// MARK: - Request / Response Models

private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
}

// MARK: - Ollama Translation Service

final class OllamaTranslationService {

    private(set) var serverURL: String
    private(set) var modelName: String

    init(serverURL: String? = nil, modelName: String? = nil) {
        let defaults = UserDefaults.standard
        self.serverURL = serverURL
            ?? defaults.string(forKey: "OllamaServerURL")
            ?? Self.defaultServerURL
        self.modelName = modelName
            ?? defaults.string(forKey: "OllamaModel")
            ?? Self.defaultModel
    }

    static let defaultServerURL = "http://localhost:11434"
    static let defaultModel = "qwen2.5"

    // MARK: - Translation

    func translate(_ text: String, from language: SourceLanguage) async throws -> String {
        let prompt = "Translate this \(language.displayName) manga text to English. Return ONLY the translation: \(text)"
        return try await generate(prompt: prompt)
    }

    // MARK: - Connectivity Check

    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(serverURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func generate(prompt: String) async throws -> String {
        guard let url = URL(string: "\(serverURL)/api/generate") else {
            throw OllamaError.unreachable
        }

        let body = OllamaGenerateRequest(model: modelName, prompt: prompt, stream: false)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw OllamaError.networkError(error)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw OllamaError.timeout
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                throw OllamaError.unreachable
            default:
                throw OllamaError.networkError(urlError)
            }
        } catch {
            throw OllamaError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.decodingError
        }

        if httpResponse.statusCode == 404 {
            throw OllamaError.modelNotFound(modelName)
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.networkError(
                NSError(domain: "OllamaService", code: httpResponse.statusCode)
            )
        }

        do {
            let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
            return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw OllamaError.decodingError
        }
    }

    // MARK: - Configuration Update

    func update(serverURL: String? = nil, modelName: String? = nil) {
        if let url = serverURL { self.serverURL = url }
        if let model = modelName { self.modelName = model }
    }
}
