//
//  AdapterRegistry.swift
//  Singularity
//

import Foundation

/// The set of web adapters the app knows about, with host-based lookup.
/// The web lane uses it to pick the right adapter for a URL, and
/// `AllowedDomains` unions their hosts into the navigation allowlist.
///
/// A value type holding `Sendable` adapters; the default set is the
/// adapters declared under `Adapters/Web/`.
struct AdapterRegistry {
    let adapters: [any WebAdapter]

    static let defaultAdapters: [any WebAdapter] = [
        YouTubeAdapter(), GmailAdapter(), SpotifyWebAdapter(),
    ]

    init(adapters: [any WebAdapter] = AdapterRegistry.defaultAdapters) {
        self.adapters = adapters
    }

    /// The adapter that declares `host` in its `allowedHosts`
    /// (case-insensitive), or `nil` if none does.
    func lookup(host: String) -> (any WebAdapter)? {
        let target = host.lowercased()
        return adapters.first { adapter in
            adapter.allowedHosts.contains { $0.lowercased() == target }
        }
    }
}
