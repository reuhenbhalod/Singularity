//
//  OllamaPlannerTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Returns queued `content` strings in order and records the messages it
/// was sent, so the planner's repair loop can be asserted without a
/// running Ollama.
private final class MockOllamaClient: OllamaClientProtocol, @unchecked Sendable {
    private var responses: [String]
    private(set) var sentMessages: [[OllamaMessage]] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func tags() async throws -> [String] { ["mock-model"] }

    func chat(
        model: String,
        messages: [OllamaMessage],
        format: OllamaFormat?,
        temperature: Double
    ) async throws -> OllamaChatResponse {
        sentMessages.append(messages)
        let content = responses.isEmpty ? "" : responses.removeFirst()
        return OllamaChatResponse(
            model: model,
            message: OllamaMessage(role: "assistant", content: content),
            done: true
        )
    }
}

/// Captures the malformed-output hashes the planner reports.
private final class HashSpy: @unchecked Sendable {
    private(set) var hashes: [String] = []
    func record(_ hash: String) { hashes.append(hash) }
}

struct OllamaPlannerTests {
    private let validPlan =
        #"{"steps":[{"action":{"kind":"web_navigate","url":"https://www.youtube.com/@MrBeast/videos"}}]}"#

    /// T-P2-04 (a): a valid response decodes into a `RawPlan`.
    @Test func validResponseReturnsPlan() async throws {
        let client = MockOllamaClient(responses: [validPlan])
        let planner = OllamaPlanner(client: client, model: "m", logMalformed: { _ in })

        let plan = try await #require(planner.plan("play mrbeast newest video"))

        #expect(plan.steps.count == 1)
        // The first request leads with the system prompt, then the input.
        #expect(client.sentMessages.first?.first?.role == "system")
        #expect(client.sentMessages.first?.last?.content == "play mrbeast newest video")
    }

    /// T-P2-04 (b): a first response that fails to decode triggers a
    /// second request containing the failing output and the error.
    @Test func repairsOnFirstDecodeFailure() async throws {
        let client = MockOllamaClient(responses: ["this is not json", #"{"steps":[]}"#])
        let spy = HashSpy()
        let planner = OllamaPlanner(client: client, model: "m", logMalformed: { spy.record($0) })

        let plan = try await #require(planner.plan("hi"))

        #expect(plan.steps.isEmpty)
        #expect(client.sentMessages.count == 2)

        let repairRequest = client.sentMessages[1]
        // Echoes the failing output back...
        #expect(repairRequest.contains { $0.content == "this is not json" })
        // ...and tells the model it failed validation.
        #expect(repairRequest.contains { $0.content.contains("failed validation") })
        // The malformed output's hash was reported once.
        #expect(spy.hashes.count == 1)
    }

    /// T-P2-04 (c): when both attempts fail, throw `unparseable` and log
    /// both malformed hashes.
    @Test func failsLoudWhenBothAttemptsFail() async throws {
        let client = MockOllamaClient(responses: ["nope", "still nope"])
        let spy = HashSpy()
        let planner = OllamaPlanner(client: client, model: "m", logMalformed: { spy.record($0) })

        await #expect(throws: PlannerError.unparseable) {
            try await planner.plan("hi")
        }
        #expect(spy.hashes.count == 2)
    }

    /// Transport failures map onto `PlannerError`.
    @Test func mapsClientErrorToPlannerError() async throws {
        struct FailingClient: OllamaClientProtocol {
            func tags() async throws -> [String] { [] }
            func chat(
                model: String,
                messages: [OllamaMessage],
                format: OllamaFormat?,
                temperature: Double
            ) async throws -> OllamaChatResponse {
                throw OllamaClientError.unreachable
            }
        }
        let planner = OllamaPlanner(client: FailingClient(), model: "m", logMalformed: { _ in })

        await #expect(throws: PlannerError.unreachable) {
            try await planner.plan("hi")
        }
    }
}
