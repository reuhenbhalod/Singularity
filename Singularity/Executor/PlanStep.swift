//
//  PlanStep.swift
//  Singularity
//

import Foundation

/// One step of a plan: the action to perform, plus future metadata
/// (target pane, risk class set by `PlanValidator` in Phase 5, etc.).
/// Phase 1 carries only the action.
struct PlanStep: Codable, Equatable {
    let action: Action
}
