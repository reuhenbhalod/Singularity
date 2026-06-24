//
//  PermissionsManager.swift
//  Singularity
//

import ApplicationServices

/// Reports the app's TCC permission state. Phase 4 covers only
/// Accessibility (research brief §9); Automation and Full Disk Access
/// states — plus caching and foreground polling — arrive in Phase 7.
///
/// The trust check is injectable so both states are unit-testable
/// without actually toggling a system permission.
@MainActor
final class PermissionsManager {
    enum Status: Equatable {
        case granted
        case denied
    }

    private let isTrusted: () -> Bool

    init(isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.isTrusted = isTrusted
    }

    /// `.granted` when the app is a trusted Accessibility client.
    var accessibility: Status {
        isTrusted() ? .granted : .denied
    }
}
