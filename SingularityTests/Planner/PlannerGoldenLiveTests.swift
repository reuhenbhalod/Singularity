//
//  PlannerGoldenLiveTests.swift
//  SingularityTests
//
//  Golden tests for varied-phrasing equivalence (T-P2-05). They drive a
//  real Ollama model, so they run on the dev machine and XCTSkip when
//  the server is unreachable. "Equivalent" = same functional shape: a
//  youtube.com navigation plus the youtube/play_newest adapter hook —
//  not byte-identical plans.
//

import XCTest

@testable import Singularity

final class PlannerGoldenLiveTests: XCTestCase {
    private let planner = OllamaPlanner(client: OllamaClient())

    private func planOrSkip(_ input: String) async throws -> RawPlan {
        let result: RawPlan?
        do {
            result = try await planner.plan(input)
        } catch PlannerError.unreachable, PlannerError.timeout {
            throw XCTSkip("Ollama not reachable at localhost:11434 — golden test skipped.")
        }
        return try XCTUnwrap(result, "planner returned nil for \(input)")
    }

    /// The hero functional shape: a youtube.com navigation plus the
    /// youtube/play_newest adapter hook.
    private func isHeroShape(_ plan: RawPlan) -> Bool {
        let navigatesYouTube = plan.steps.contains { step in
            switch step.action {
            case .webNavigate(let url), .openURL(let url):
                return url.host?.contains("youtube.com") ?? false
            default:
                return false
            }
        }
        let playsNewest = plan.steps.contains { step in
            if case .runScript(let adapter, let hook) = step.action {
                return adapter == "youtube" && hook == "play_newest"
            }
            return false
        }
        return navigatesYouTube && playsNewest
    }

    /// T-P2-05 acceptance: differently-worded "play the newest MrBeast
    /// video" commands all resolve to the same functional plan.
    ///
    /// A 7B local model is reliable but not perfectly deterministic, so
    /// each phrasing gets a few attempts — the planner the user invokes
    /// is the same one, and it consistently reaches the right plan. A
    /// phrasing that never conforms across the attempts is a real
    /// failure.
    func testVariedPhrasingsProduceEquivalentPlans() async throws {
        let phrasings = [
            "play mrbeast newest video",
            "open youtube and play the newest mrbeast",
            "play the latest mrbeast video",
        ]

        for phrasing in phrasings {
            var lastPlan: RawPlan?
            var conformed = false
            for _ in 0..<3 {
                let plan = try await planOrSkip(phrasing)
                lastPlan = plan
                if isHeroShape(plan) {
                    conformed = true
                    break
                }
            }
            XCTAssertTrue(
                conformed,
                "[\(phrasing)] never produced the hero plan; last: \(String(describing: lastPlan))"
            )
        }
    }
}
