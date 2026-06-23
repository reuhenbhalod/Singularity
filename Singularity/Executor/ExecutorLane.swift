//
//  ExecutorLane.swift
//  Singularity
//

import Foundation

/// One lane of the executor waterfall (research brief §10). The router
/// asks each registered lane, in order, whether it `canHandle` a step;
/// the first that says yes runs it via `execute`. This is what replaces
/// the Phase-1 hardcoded hero routing (T-P3-02 wires it up).
///
/// `@MainActor` because lanes drive main-actor-bound APIs (`WKWebView`,
/// `NSWorkspace`, Accessibility).
@MainActor
protocol ExecutorLane {
    /// Whether this lane knows how to run `step`.
    func canHandle(_ step: PlanStep) -> Bool

    /// Runs `step`, returning a user-facing result. Only called when
    /// `canHandle(step)` is true.
    func execute(_ step: PlanStep) async throws -> LaneResult
}
