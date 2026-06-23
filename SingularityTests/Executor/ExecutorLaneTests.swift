//
//  ExecutorLaneTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// A test double proving the protocol is conformable and callable.
@MainActor
private final class FakeLane: ExecutorLane {
    let handledKinds: (PlanStep) -> Bool
    private(set) var executed: [PlanStep] = []

    init(canHandle: @escaping (PlanStep) -> Bool) {
        self.handledKinds = canHandle
    }

    func canHandle(_ step: PlanStep) -> Bool { handledKinds(step) }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        executed.append(step)
        return .handled(summary: "ran \(step.action)")
    }
}

@MainActor
struct ExecutorLaneTests {
    /// T-P3-01: a conforming lane reports what it handles and runs it.
    @Test func laneHandlesAndExecutes() async throws {
        let lane = FakeLane { step in
            if case .openURL = step.action { return true }
            return false
        }
        let url = try #require(URL(string: "spotify:track:123"))
        let step = PlanStep(action: .openURL(url))

        #expect(lane.canHandle(step))
        let result = try await lane.execute(step)
        if case .handled = result {
        } else {
            Issue.record("expected .handled, got \(result)")
        }
        #expect(lane.executed.count == 1)
    }

    /// A lane declines steps it doesn't recognize.
    @Test func laneDeclinesUnknownStep() throws {
        let lane = FakeLane { _ in false }
        let url = try #require(URL(string: "https://example.com"))
        #expect(!lane.canHandle(PlanStep(action: .webNavigate(url))))
    }
}
