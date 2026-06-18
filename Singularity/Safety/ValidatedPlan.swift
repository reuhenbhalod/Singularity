//
//  ValidatedPlan.swift
//  Singularity
//

import Foundation

/// The only plan type the executor will accept (T-P5-05 enforces
/// this end-to-end). Construction is gated: the `init` is private,
/// so the only way to produce a `ValidatedPlan` is through a factory
/// owned by `PlanValidator` (Phase 5) or — TEMPORARILY — the
/// `phase1Allow` shim below.
///
/// The shim exists so Phase 1 can drive a plan through the executor
/// before the real PlanValidator is built. T-P5-05 must DELETE
/// `phase1Allow` and make `PlanValidator.validate(_:)` the only
/// constructor; that change is the architect's flagged "hardest
/// task" because it removes the only escape hatch and the rest of
/// the codebase has to compile without it.
struct ValidatedPlan: Equatable {
    let steps: [PlanStep]

    private init(steps: [PlanStep]) {
        self.steps = steps
    }

    /// PHASE 1 ONLY — bypass the (not-yet-existing) safety pipeline
    /// and wrap a `RawPlan` as `ValidatedPlan`. REMOVE in T-P5-05.
    /// Any code that calls this after Phase 5 is shipped is a bug.
    static func phase1Allow(_ raw: RawPlan) -> ValidatedPlan {
        ValidatedPlan(steps: raw.steps)
    }
}
