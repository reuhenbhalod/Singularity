//
//  PlannerProtocol.swift
//  Singularity
//

import Foundation

/// Turns raw user input into a `RawPlan`.
///
/// Phase 1 has only `StringMatcherPlanner` (hardcoded recognition of
/// the hero command). Phase 2 introduces `OllamaPlanner`. Both are
/// interchangeable behind this protocol so the rest of the system
/// doesn't need to know which one is running.
protocol PlannerProtocol: Sendable {
    /// Returns `nil` if the input is not recognized. Throws only on
    /// transport / decoding errors (the Phase 1 string matcher never
    /// throws; Phase 2's OllamaPlanner can throw `OllamaError`).
    func plan(_ input: String) async throws -> RawPlan?
}
