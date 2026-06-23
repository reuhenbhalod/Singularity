//
//  ExecutorRouterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Records which steps it ran and returns a per-call summary.
@MainActor
private final class RecordingLane: ExecutorLane {
    private let handles: (PlanStep) -> Bool
    private(set) var executed: [PlanStep] = []

    init(handles: @escaping (PlanStep) -> Bool) {
        self.handles = handles
    }

    func canHandle(_ step: PlanStep) -> Bool { handles(step) }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        executed.append(step)
        return .handled(summary: "call \(executed.count)")
    }
}

@MainActor
struct ExecutorRouterTests {
    private func plan(_ actions: [Action]) -> ValidatedPlan {
        .phase1Allow(RawPlan(steps: actions.map { PlanStep(action: $0) }))
    }

    /// T-P3-02: each step goes to the first lane whose canHandle is true.
    @Test func dispatchesToFirstCapableLane() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let urlLane = RecordingLane { if case .openURL = $0.action { return true } else { return false } }
        let webLane = RecordingLane { if case .webNavigate = $0.action { return true } else { return false } }
        let router = ExecutorRouter(lanes: [urlLane, webLane])

        let result = try await router.dispatch(plan([.webNavigate(url)]))

        #expect(result == .handled(summary: "call 1"))
        #expect(webLane.executed.count == 1)
        #expect(urlLane.executed.isEmpty)
    }

    /// First-match-wins: an earlier lane that also matches is preferred.
    @Test func earlierLaneWinsWhenBothMatch() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let first = RecordingLane { _ in true }
        let second = RecordingLane { _ in true }
        let router = ExecutorRouter(lanes: [first, second])

        _ = try await router.dispatch(plan([.webNavigate(url)]))

        #expect(first.executed.count == 1)
        #expect(second.executed.isEmpty)
    }

    /// T-P3-02: no matching lane -> `.unhandled`.
    @Test func unhandledWhenNoLaneMatches() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let lane = RecordingLane { _ in false }
        let router = ExecutorRouter(lanes: [lane])

        let result = try await router.dispatch(plan([.webNavigate(url)]))

        #expect(result == .unhandled)
    }

    /// Multi-step: returns the last handled step's result.
    @Test func returnsLastStepResult() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let lane = RecordingLane { _ in true }
        let router = ExecutorRouter(lanes: [lane])

        let result = try await router.dispatch(plan([.webNavigate(url), .webNavigate(url)]))

        #expect(result == .handled(summary: "call 2"))
        #expect(lane.executed.count == 2)
    }

    /// An unhandled step short-circuits the rest of the plan.
    @Test func unhandledStepStopsDispatch() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let lane = RecordingLane { _ in false }
        let router = ExecutorRouter(lanes: [lane])

        let result = try await router.dispatch(plan([.webNavigate(url), .webNavigate(url)]))

        #expect(result == .unhandled)
        #expect(lane.executed.isEmpty)
    }
}
