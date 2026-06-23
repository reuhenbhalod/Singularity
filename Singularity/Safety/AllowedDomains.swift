//
//  AllowedDomains.swift
//  Singularity
//

import Foundation

/// The read-only navigation allowlist: the lower-cased union of every
/// web adapter's `allowedHosts` (research brief §11.4). `URLPolicy`
/// consults it to decide whether a web pane may navigate to a host.
///
/// Keeping the source of truth per-adapter (and just union-ing here)
/// means adding or removing an adapter is a one-file change, not a
/// cross-file coordination problem.
struct AllowedDomains {
    let all: Set<String>

    init(registry: AdapterRegistry = AdapterRegistry()) {
        all = Set(registry.adapters.flatMap(\.allowedHosts).map { $0.lowercased() })
    }

    /// Whether `host` is allowed (case-insensitive exact match). IDN
    /// hosts are compared in their ASCII `xn--` form, which round-trips
    /// unchanged through lowercasing.
    func contains(_ host: String) -> Bool {
        all.contains(host.lowercased())
    }
}
