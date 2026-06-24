//
//  AXAdapter.swift
//  Singularity
//

import Foundation

/// A per-app driver for the Accessibility (lane 3) executor — the AX
/// counterpart of `WebAdapter`. Each adapter owns the AX traversal for
/// one native app (Spotify, Mail, …): the planner only names the
/// adapter and a hook (`ax_action(adapter:hook:)`), and the adapter
/// knows how to find and drive the controls.
///
/// `Sendable` (adapters are value types holding only constants); the
/// `perform` work is `@MainActor` because it makes synchronous AX IPC.
protocol AXAdapter: Sendable {
    /// The name the planner uses (e.g. `"spotify"`).
    var name: String { get }
    /// The target app's bundle identifier (e.g. `"com.spotify.client"`).
    var bundleID: String { get }
    /// The hooks this adapter supports (e.g. `["playpause"]`).
    var hooks: Set<String> { get }

    /// Runs `hook` against the app's AX tree and returns a short,
    /// user-facing summary. Throws `AXErrors` on AX failure.
    @MainActor
    func perform(_ hook: String, in app: AXApplication) throws -> String
}
