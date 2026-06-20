//
//  StringMatcherPlannerTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct StringMatcherPlannerTests {
    /// T-P1-03 acceptance: `play mrbeast newest video` resolves to a
    /// two-step plan — webNavigate to the MrBeast channel + runScript
    /// for the YouTube adapter's play_newest hook.
    @Test func playMrBeastNewestVideoResolvesToTwoStepPlan() async throws {
        let planner = StringMatcherPlanner()

        let plan = try await #require(planner.plan("play mrbeast newest video"))

        #expect(plan.steps.count == 2)

        guard case .webNavigate(let url) = plan.steps[0].action else {
            Issue.record("expected webNavigate as step 0, got \(plan.steps[0].action)")
            return
        }
        #expect(url.absoluteString == "https://www.youtube.com/@MrBeast/videos")

        guard case .runScript(let adapter, let hook) = plan.steps[1].action else {
            Issue.record("expected runScript as step 1, got \(plan.steps[1].action)")
            return
        }
        #expect(adapter == "youtube")
        #expect(hook == "play_newest")
    }

    /// Normalization: matches case-insensitively and ignores
    /// surrounding whitespace.
    @Test func matchesAreCaseInsensitiveAndTrimmed() async throws {
        let planner = StringMatcherPlanner()
        for input in [
            "Play MrBeast Newest Video",
            "PLAY MRBEAST NEWEST VIDEO",
            "  play mrbeast newest video  ",
            "play mrbeast newest video\n",
        ] {
            _ = try await #require(
                planner.plan(input),
                "expected \(input) to resolve"
            )
        }
    }

    /// T-P1-03 acceptance: unrecognized inputs return nil (Phase 1
    /// has no other phrases).
    @Test func unrecognizedInputReturnsNil() async throws {
        let planner = StringMatcherPlanner()
        for input in ["", "hello", "open spotify", "play mrbeast", "play mrbeast oldest video"] {
            let plan = try await planner.plan(input)
            #expect(plan == nil, "expected nil for '\(input)' but got a plan")
        }
    }
}
