//
//  LaneResult.swift
//  Singularity
//

import Foundation

/// The outcome of routing one plan step through the executor waterfall.
///
/// A lane that handles a step returns `.handled` with a short,
/// user-facing summary the pipeline logs. The router returns
/// `.unhandled` when no lane's `canHandle(_:)` matched, so the pipeline
/// can tell the user it couldn't carry that step out.
enum LaneResult: Equatable {
    case handled(summary: String)
    case unhandled
}
