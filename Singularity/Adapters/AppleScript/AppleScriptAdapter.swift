//
//  AppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// A per-app driver for the AppleScript (lane 4) executor — the Apple-app
/// counterpart of `AXAdapter` (research brief §6). Each adapter maps
/// planner-facing hook names to AppleScript source. The planner only
/// names the adapter and a hook; the adapter owns the script.
///
/// Hooks are parameterless (the plan schema carries no free-form
/// arguments), so v1 adapters expose control/read operations
/// (play/pause, next, "what's playing", counts) rather than
/// create-with-content ops.
///
/// `Sendable` (value types holding only constant strings).
protocol AppleScriptAdapter: Sendable {
    /// The name the planner uses (e.g. `"music"`).
    var name: String { get }

    /// Hook name → AppleScript source.
    var scripts: [String: String] { get }
}
