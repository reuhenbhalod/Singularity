//
//  PermissionsManager.swift
//  Singularity
//

import ApplicationServices
import Foundation

/// The three TCC permissions the shell can need. Kept in one place so the
/// Permissions tab, the first-run checklist, and the revocation banner all
/// speak the same language.
enum PermissionKind: String, CaseIterable, Identifiable {
    case accessibility
    case automation
    case fullDiskAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .automation: return "Automation"
        case .fullDiskAccess: return "Full Disk Access"
        }
    }

    /// Plain-language reason, so a denied permission explains itself.
    var why: String {
        switch self {
        case .accessibility:
            return "Lets the shell read and click UI in other apps (the Accessibility lane)."
        case .automation:
            return "Lets the shell drive apps with AppleScript (mail, notes, system apps)."
        case .fullDiskAccess:
            return "Lets file commands reach protected folders like Mail and Messages."
        }
    }
}

/// Reports the app's TCC permission state (research brief §9, §12.5).
/// Accessibility and Full Disk Access are probed live; Automation is
/// event-driven — the AppleScript lane feeds each call's result in, since
/// macOS gives no way to read Automation state without triggering a prompt.
///
/// Everything is injectable so all three states are unit-testable without
/// toggling a real system permission.
@MainActor
@Observable
final class PermissionsManager {
    enum Status: Equatable {
        case granted
        case denied
        /// Not yet determined (e.g. Automation before the first AppleScript
        /// call, or an FDA probe that hit neither success nor EPERM).
        case unknown
    }

    private(set) var accessibility: Status
    private(set) var fullDiskAccess: Status
    private(set) var automation: Status = .unknown

    @ObservationIgnored private let isTrusted: () -> Bool
    @ObservationIgnored private let fdaProbe: () -> Status
    @ObservationIgnored private var pollTimer: Timer?

    init(
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        fdaProbe: @escaping () -> Status = PermissionsManager.defaultFDAProbe
    ) {
        self.isTrusted = isTrusted
        self.fdaProbe = fdaProbe
        self.accessibility = isTrusted() ? .granted : .denied
        self.fullDiskAccess = fdaProbe()
    }

    func status(of kind: PermissionKind) -> Status {
        switch kind {
        case .accessibility: return accessibility
        case .automation: return automation
        case .fullDiskAccess: return fullDiskAccess
        }
    }

    /// Re-reads the live permissions (Accessibility, Full Disk Access).
    /// Automation is left alone — it only changes when the AppleScript lane
    /// reports a fresh result.
    func refresh() {
        accessibility = isTrusted() ? .granted : .denied
        fullDiskAccess = fdaProbe()
    }

    /// Folds an AppleScript call's OSStatus into the Automation cache:
    /// `errAEEventNotPermitted` (-1743) → denied, success → granted. Other
    /// errors say nothing about permission and are ignored.
    func recordAutomationResult(errorCode: Int?) {
        switch errorCode {
        case nil, 0:
            automation = .granted
        case -1743:
            automation = .denied
        default:
            break
        }
    }

    /// Any required permission currently denied (drives the banner).
    var deniedKinds: [PermissionKind] {
        PermissionKind.allCases.filter { status(of: $0) == .denied }
    }

    var hasDeniedPermission: Bool { !deniedKinds.isEmpty }

    // MARK: - Foreground polling (T-P7-06)

    /// Polls the live permissions every 2s. The Permissions tab starts this
    /// on appear and stops on disappear, so we only poll while foreground.
    func startPolling(interval: TimeInterval = 2) {
        stopPolling()
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Full Disk Access probe

    /// Reads a TCC-protected path (the user's TCC database) and classifies
    /// the result: openable → granted, `EPERM` → denied, anything else
    /// (e.g. the file is absent) → unknown.
    nonisolated static func defaultFDAProbe() -> Status {
        let path = ("~/Library/Application Support/com.apple.TCC/TCC.db" as NSString)
            .expandingTildeInPath
        let descriptor = open(path, O_RDONLY)
        if descriptor >= 0 {
            close(descriptor)
            return .granted
        }
        return errno == EPERM ? .denied : .unknown
    }
}
