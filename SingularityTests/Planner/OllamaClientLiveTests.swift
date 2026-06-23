//
//  OllamaClientLiveTests.swift
//  SingularityTests
//
//  Integration tests that hit a real Ollama server at localhost:11434.
//  They run when Ollama is up (the dev machine, after T-P2-01) and
//  XCTSkip cleanly otherwise, so the suite stays green without it.
//

import XCTest

@testable import Singularity

final class OllamaClientLiveTests: XCTestCase {
    private let client = OllamaClient(timeout: 120)

    /// Gated live access; returns the installed model names.
    private func reachableModelsOrSkip() async throws -> [String] {
        try await LiveTestGate.requireLiveOllama()
        return try await client.tags()
    }

    /// T-P2-02 acceptance: `tags()` returns a non-empty model list.
    func testTagsReturnsAtLeastOneModel() async throws {
        let models = try await reachableModelsOrSkip()
        XCTAssertFalse(models.isEmpty, "expected at least one pulled model")
    }

    /// T-P2-02 acceptance: `chat(...)` returns a decodable response with
    /// non-empty content.
    func testChatReturnsDecodableResponse() async throws {
        let models = try await reachableModelsOrSkip()
        guard let model = models.first else {
            throw XCTSkip("No model installed; run `ollama pull`.")
        }

        let response = try await client.chat(
            model: model,
            messages: [
                OllamaMessage(role: "user", content: "Reply with a JSON object: {\"ok\": true}")
            ],
            format: .json,
            temperature: 0
        )

        XCTAssertEqual(response.model, model)
        XCTAssertFalse(response.message.content.isEmpty)
        XCTAssertTrue(response.done)
    }
}
