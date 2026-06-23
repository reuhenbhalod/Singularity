//
//  URLOpening.swift
//  Singularity
//

import AppKit

/// Opens a URL with the system handler. Abstracted so `URLSchemeLane`
/// can be tested without actually launching apps.
@MainActor
protocol URLOpening {
    /// Hands `url` to the system. Returns whether a handler accepted it.
    @discardableResult
    func open(_ url: URL) -> Bool
}

/// Production opener backed by `NSWorkspace`.
struct WorkspaceURLOpener: URLOpening {
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
