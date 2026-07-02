//
//  AppleScriptAdapterRegistry.swift
//  Singularity
//

import Foundation

/// The AppleScript adapters the app knows about, looked up by the
/// planner-facing name (the AppleScript counterpart of `AXAdapterRegistry`).
struct AppleScriptAdapterRegistry {
    let adapters: [any AppleScriptAdapter]

    static let defaultAdapters: [any AppleScriptAdapter] = [
        MusicAppleScriptAdapter(),
        FinderAppleScriptAdapter(),
    ]

    init(adapters: [any AppleScriptAdapter] = AppleScriptAdapterRegistry.defaultAdapters) {
        self.adapters = adapters
    }

    func adapter(named name: String) -> (any AppleScriptAdapter)? {
        adapters.first { $0.name == name }
    }
}
