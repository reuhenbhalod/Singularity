//
//  LaneResult.swift
//  Singularity
//

import Foundation

/// The outcome of routing one plan step through the executor waterfall.
///
/// A lane that handles a step returns `.handled` with a short,
/// user-facing summary the pipeline logs. When no lane's `canHandle(_:)`
/// matched, the router returns `.unhandled` carrying an honest,
/// user-facing **reason** — what's missing and, where possible, what the
/// shell *can* do — so the user is told why instead of a flat failure.
enum LaneResult: Equatable {
    case handled(summary: String)
    case unhandled(reason: String)
}
