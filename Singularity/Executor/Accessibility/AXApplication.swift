//
//  AXApplication.swift
//  Singularity
//

import AppKit
import ApplicationServices

/// The Accessibility root of a running application, found by bundle ID
/// (research brief §5). Creating the root element does NOT require
/// Accessibility permission; reading its tree does.
///
/// Cache and reuse the root rather than re-resolving per query — AX
/// traversal is synchronous IPC and re-walking from the root is slow.
@MainActor
struct AXApplication {
    /// The app's root AX element.
    let root: AXElement

    /// Fails (returns nil) if no running app has `bundleId`.
    init?(bundleId: String) {
        guard
            let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleId
            })
        else {
            return nil
        }
        root = AXElement(element: AXUIElementCreateApplication(app.processIdentifier))
    }
}
