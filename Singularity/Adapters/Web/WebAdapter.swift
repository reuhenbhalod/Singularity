//
//  WebAdapter.swift
//  Singularity
//

import Foundation

/// A per-app driver for the WKWebView (lane 2) executor.
///
/// Each adapter owns the resilient selectors and JavaScript hooks for
/// one web app (YouTube, Gmail, …). The planner only *names* an adapter
/// and a hook (`runScript(adapter:hook:)`); the adapter is what knows
/// how to actually drive the page. Keeping the selectors here — not in
/// the planner — means a site redesign is a one-file fix.
///
/// Phase 1 keeps this protocol intentionally thin: just the navigation
/// allowlist, which `URLPolicy` will union across all adapters in
/// Phase 3 (T-P3-05) to form the global host allowlist. Phase 3 grows
/// this protocol with `dataStoreIdentifier`, `allowsDownloads`, and a
/// protocol-level `contentWorldName` once there is more than one
/// adapter to share them.
///
/// `Sendable` so an adapter can be handed to the executor across actor
/// boundaries; adapters are value types holding only constants.
protocol WebAdapter: Sendable {
    /// Hosts this adapter is permitted to drive. The web lane refuses
    /// to navigate anywhere outside the union of every adapter's
    /// `allowedHosts`. Compared case-insensitively (see `URLPolicy`).
    var allowedHosts: [String] { get }

    /// Stable identifier for this adapter's persistent
    /// `WKWebsiteDataStore` (cookies, localStorage). Each adapter gets
    /// its own isolated store so logins persist across launches and one
    /// app's session can't read another's. Must be a fixed constant —
    /// a fresh UUID per launch would orphan the previous session's
    /// login. (Pulled forward from Phase 3 because `WebPaneController`
    /// needs it now, per T-P1-07.)
    var dataStoreIdentifier: UUID { get }

    /// Whether this adapter's panes may download files. Defaults to
    /// `false` (deny) — an adapter opts in only when a hook genuinely
    /// needs it (e.g. "save attachment").
    var allowsDownloads: Bool { get }

    /// A custom User-Agent for this adapter's panes, or `nil` to use
    /// WKWebView's default. WKWebView's default UA omits the
    /// `Version/… Safari/…` suffix that real Safari sends, and some sites
    /// (Spotify) sniff that and serve a broken / "unsupported browser"
    /// layout. Declaring a desktop Safari UA makes them render the proper
    /// experience. Defaults to `nil` (sites that work on the default,
    /// like YouTube, leave it alone).
    var userAgent: String? { get }
}

extension WebAdapter {
    var allowsDownloads: Bool { false }
    var userAgent: String? { nil }
}
