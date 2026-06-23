//
//  ExecutorRouter.swift
//  Singularity
//

import Foundation

/// Runs a `ValidatedPlan` through the executor waterfall: for each step,
/// the first registered lane whose `canHandle(_:)` returns true runs it
/// (research brief §10). Returns the last handled step's result, or
/// `.unhandled` at the first step no lane can take.
///
/// Accepts only `ValidatedPlan` — never `RawPlan` — so an unvalidated
/// plan cannot reach execution (the type-level gate of brief §11.3).
@MainActor
final class ExecutorRouter {
    private let lanes: [any ExecutorLane]

    init(lanes: [any ExecutorLane]) {
        self.lanes = lanes
    }

    /// Dispatches every step in order. Stops and returns `.unhandled`
    /// at the first step no lane handles; otherwise returns the last
    /// step's `LaneResult`.
    @discardableResult
    func dispatch(_ plan: ValidatedPlan) async throws -> LaneResult {
        var last: LaneResult = .handled(summary: "done")
        for step in plan.steps {
            let result = try await dispatch(step)
            if case .unhandled = result {
                return .unhandled
            }
            last = result
        }
        return last
    }

    private func dispatch(_ step: PlanStep) async throws -> LaneResult {
        for lane in lanes where lane.canHandle(step) {
            return try await lane.execute(step)
        }
        return .unhandled
    }
}
