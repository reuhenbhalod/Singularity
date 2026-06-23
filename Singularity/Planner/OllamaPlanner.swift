//
//  OllamaPlanner.swift
//  Singularity
//

import CryptoKit
import Foundation
import os

/// `PlannerProtocol` backed by a local Ollama model. Sends the system
/// prompt + the user's command with `format: <schema>` and
/// `temperature: 0`, then runs the validate → repair-once → fail-loud
/// loop from research brief §1:
///
/// 1. Decode the response into a `RawPlan`.
/// 2. On failure, re-prompt once with the failing output and the decode
///    error appended.
/// 3. If the second attempt also fails, throw `PlannerError.unparseable`.
///
/// Raw model output is never logged; only a SHA-256 hash of malformed
/// output is reported (at `.private`) so failures are traceable without
/// leaking content. The hash sink is injectable so tests can observe it.
struct OllamaPlanner: PlannerProtocol {
    private let client: any OllamaClientProtocol
    private let model: String
    private let logMalformed: @Sendable (String) -> Void

    init(
        client: any OllamaClientProtocol,
        model: String = "qwen2.5-coder:7b-instruct-q4_K_M",
        logMalformed: @escaping @Sendable (String) -> Void = OllamaPlanner.osLogMalformed
    ) {
        self.client = client
        self.model = model
        self.logMalformed = logMalformed
    }

    func plan(_ input: String) async throws -> RawPlan? {
        var messages = [
            OllamaMessage(role: "system", content: SystemPrompt.text),
            OllamaMessage(role: "user", content: input),
        ]

        let first = try await content(for: messages)
        switch Self.decode(first) {
        case .success(let plan):
            return plan
        case .failure(let error):
            // Validate -> repair once: feed back the failing output and
            // the error so the model can correct itself.
            logMalformed(Self.hash(first))
            messages.append(OllamaMessage(role: "assistant", content: first))
            messages.append(
                OllamaMessage(
                    role: "user",
                    content: "Your last response failed validation: \(error). "
                        + "Return ONLY valid JSON matching the schema, nothing else."
                )
            )
        }

        let second = try await content(for: messages)
        switch Self.decode(second) {
        case .success(let plan):
            return plan
        case .failure:
            // Fail loud — do not fall through to a best-effort plan.
            logMalformed(Self.hash(second))
            throw PlannerError.unparseable
        }
    }

    // MARK: - Internals

    private func content(for messages: [OllamaMessage]) async throws -> String {
        do {
            let response = try await client.chat(
                model: model,
                messages: messages,
                format: PlanSchema.ollamaFormat,
                temperature: 0
            )
            return response.message.content
        } catch let error as OllamaClientError {
            throw Self.plannerError(from: error)
        }
    }

    private static func decode(_ content: String) -> Result<RawPlan, any Error> {
        Result { try JSONDecoder().decode(RawPlan.self, from: Data(content.utf8)) }
    }

    private static func hash(_ content: String) -> String {
        SHA256.hash(data: Data(content.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func plannerError(from error: OllamaClientError) -> PlannerError {
        switch error {
        case .unreachable: return .unreachable
        case .timeout: return .timeout
        case .server(let status): return .transport("HTTP \(status)")
        case .transport(let message): return .transport(message)
        case .decoding(let message): return .transport(message)
        }
    }

    /// Default malformed-output sink: logs only the hash, at `.private`.
    static let osLogMalformed: @Sendable (String) -> Void = { hash in
        Logger(subsystem: "com.reuhenbhalod.Singularity", category: "planner")
            .error("malformed plan output, hash=\(hash, privacy: .private)")
    }
}
