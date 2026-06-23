//
//  PlannerError.swift
//  Singularity
//

import Foundation

/// User-facing planner failures. The shell turns these into a short
/// message; `unparseable` is the "I didn't understand — rephrase" case
/// after the validate → repair-once loop gives up (research brief §1).
enum PlannerError: Error, Equatable {
    /// The model's output couldn't be decoded into a plan, even after
    /// one repair attempt.
    case unparseable
    /// The Ollama server couldn't be reached.
    case unreachable
    /// The request timed out.
    case timeout
    /// Some other transport failure (carries a short description).
    case transport(String)
}
