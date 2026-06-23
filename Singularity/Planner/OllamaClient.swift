//
//  OllamaClient.swift
//  Singularity
//

import Foundation

/// Async HTTP client for a local Ollama server (`localhost:11434` by
/// default). Wraps `/api/tags` and `/api/chat` and maps URL/HTTP
/// failures onto typed `OllamaClientError`s.
///
/// `final` with immutable, `Sendable` stored properties so it satisfies
/// `OllamaClientProtocol`'s `Sendable` requirement.
final class OllamaClient: OllamaClientProtocol {
    private let baseURL: URL
    private let timeout: TimeInterval
    private let session: URLSession

    static let defaultBaseURL: URL = {
        // swiftlint:disable:next force_unwrapping
        URL(string: "http://localhost:11434")!
    }()

    init(
        baseURL: URL = OllamaClient.defaultBaseURL,
        timeout: TimeInterval = 30,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func tags() async throws -> [String] {
        var request = URLRequest(url: baseURL.appending(path: "api/tags"))
        request.timeoutInterval = timeout

        let (data, response) = try await send(request)
        try checkStatus(response)

        do {
            return try JSONDecoder().decode(TagsResponse.self, from: data).models.map(\.name)
        } catch {
            throw OllamaClientError.decoding(String(describing: error))
        }
    }

    func chat(
        model: String,
        messages: [OllamaMessage],
        format: OllamaFormat?,
        temperature: Double
    ) async throws -> OllamaChatResponse {
        var request = URLRequest(url: baseURL.appending(path: "api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: model,
            messages: messages,
            stream: false,
            format: format,
            options: ChatOptions(temperature: temperature)
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw OllamaClientError.decoding(String(describing: error))
        }

        let (data, response) = try await send(request)
        try checkStatus(response)

        do {
            return try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        } catch {
            throw OllamaClientError.decoding(String(describing: error))
        }
    }

    // MARK: - Internals

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw OllamaClientError.timeout
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                throw OllamaClientError.unreachable
            default:
                throw OllamaClientError.transport(error.localizedDescription)
            }
        }
    }

    private func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaClientError.server(status: http.statusCode)
        }
    }
}

// MARK: - Wire DTOs

private struct TagsResponse: Decodable {
    let models: [TagsModel]
}

private struct TagsModel: Decodable {
    let name: String
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let format: OllamaFormat?
    let options: ChatOptions
}

private struct ChatOptions: Encodable {
    let temperature: Double
}
