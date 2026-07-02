//
//  SystemSettingsLinks.swift
//  Singularity
//

import AppKit

/// Deep links into the right System Settings > Privacy & Security pane for
/// each permission, with a fallback to the parent pane if the specific
/// anchor ever stops resolving (research brief §12.5). macOS keeps the old
/// `x-apple.systempreferences:` scheme working on 14 and 15.
enum SystemSettingsLinks {
    static func url(for kind: PermissionKind) -> URL {
        let anchor: String
        switch kind {
        case .accessibility: anchor = "Privacy_Accessibility"
        case .automation: anchor = "Privacy_Automation"
        case .fullDiskAccess: anchor = "Privacy_AllFiles"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }

    /// The parent Privacy & Security pane — the fallback target.
    static var privacyRoot: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
    }

    /// Opens the pane for `kind`; if that specific link fails to open,
    /// falls back to the Privacy & Security root so the user still lands
    /// somewhere useful.
    @MainActor
    @discardableResult
    static func open(_ kind: PermissionKind, workspace: NSWorkspace = .shared) -> Bool {
        if workspace.open(url(for: kind)) { return true }
        return workspace.open(privacyRoot)
    }
}
