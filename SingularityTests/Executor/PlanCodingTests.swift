//
//  PlanCodingTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct PlanCodingTests {
    /// T-P1-01 acceptance: a minimal RawPlan with an open_url step
    /// round-trips through JSON.
    @Test func openURLPlanRoundTripsThroughJSON() throws {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://www.youtube.com/results?search_query=mrbeast")!
        let original = RawPlan(steps: [PlanStep(action: .openURL(url))])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RawPlan.self, from: data)

        #expect(decoded == original)
    }

    @Test func openURLEmitsExpectedJSONShape() throws {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://youtube.com/")!
        let plan = RawPlan(steps: [PlanStep(action: .openURL(url))])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(plan)
        let json = try #require(String(bytes: data, encoding: .utf8))

        // Discriminator is snake_case so the Ollama JSON schema in
        // Phase 2 can use the same kind names.
        #expect(json.contains("\"kind\":\"open_url\""))
        #expect(json.contains("\"url\":\"https:\\/\\/youtube.com\\/\""))
    }

    @Test func webNavigateAndWebEvaluateRoundTripToo() throws {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://www.youtube.com/watch?v=abc")!
        let plan = RawPlan(steps: [
            PlanStep(action: .webNavigate(url)),
            PlanStep(action: .webEvaluate(script: "document.querySelector('video')?.play();")),
        ])

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(RawPlan.self, from: data)

        #expect(decoded == plan)
        #expect(decoded.steps.count == 2)
    }

    @Test func decodingUnknownKindFails() {
        let badJSON = #"{"steps":[{"action":{"kind":"telepathy","url":"x"}}]}"#
        // swiftlint:disable:next force_unwrapping
        let data = badJSON.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(RawPlan.self, from: data)
        }
    }
}
