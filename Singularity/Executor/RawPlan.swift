//
//  RawPlan.swift
//  Singularity
//

import Foundation

/// Output of the `Planner` stage: an ordered list of steps that have
/// not yet been validated. Only `PlanValidator` (T-P5-04..05) can
/// produce a `ValidatedPlan`, and only `ValidatedPlan` reaches the
/// executor. `RawPlan` is what crosses the wire from Ollama.
struct RawPlan: Codable, Equatable {
    let steps: [PlanStep]
}
