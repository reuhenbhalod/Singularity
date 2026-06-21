//
//  ExecutorError.swift
//  Singularity
//

import Foundation

/// Failures the executor router can surface. Phase 1 only routes the
/// hero plan (web navigate + YouTube `play_newest`); anything else is
/// `unsupportedStep`. Phase 3 generalizes this into the lane waterfall.
enum ExecutorError: Error, Equatable {
    /// A step the Phase-1 router doesn't know how to handle.
    case unsupportedStep

    /// A `run_script` step arrived with no web pane to run it against
    /// (e.g. `play_newest` before any `web_navigate`).
    case missingPane
}
