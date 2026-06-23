//
//  OllamaClientProtocol.swift
//  Singularity
//

import Foundation

/// The Ollama HTTP surface the planner needs. Abstracted so
/// `OllamaPlanner` (T-P2-04) can be unit-tested against a mock without
/// a running server.
protocol OllamaClientProtocol: Sendable {
    /// Names of the models the server has available (`/api/tags`).
    func tags() async throws -> [String]

    /// Runs a non-streaming chat completion (`/api/chat`). `format`
    /// constrains the output (schema or loose JSON); `temperature` is
    /// usually 0 for deterministic planning.
    func chat(
        model: String,
        messages: [OllamaMessage],
        format: OllamaFormat?,
        temperature: Double
    ) async throws -> OllamaChatResponse
}
