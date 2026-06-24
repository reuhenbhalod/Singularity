//
//  AXAdapterRegistry.swift
//  Singularity
//

import Foundation

/// The set of Accessibility adapters the app knows about, looked up by
/// the planner-facing name. The AX lane uses it to find the adapter for
/// an `ax_action` step (the AX counterpart of `AdapterRegistry`).
struct AXAdapterRegistry {
    let adapters: [any AXAdapter]

    static let defaultAdapters: [any AXAdapter] = [SpotifyAXAdapter()]

    init(adapters: [any AXAdapter] = AXAdapterRegistry.defaultAdapters) {
        self.adapters = adapters
    }

    /// The adapter registered under `name`, or nil.
    func adapter(named name: String) -> (any AXAdapter)? {
        adapters.first { $0.name == name }
    }
}
