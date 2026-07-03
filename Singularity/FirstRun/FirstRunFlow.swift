//
//  FirstRunFlow.swift
//  Singularity
//

import Foundation

/// Tracks whether the one-time first-run onboarding has been shown
/// (T-P7-08). A single UserDefaults flag — nothing more is remembered.
struct FirstRunFlow {
    private let defaults: UserDefaults
    private let key = "firstRun.completed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldShow: Bool { !defaults.bool(forKey: key) }

    func markComplete() {
        defaults.set(true, forKey: key)
    }

    /// Re-arms onboarding so it shows again on next launch — used after
    /// sign-out / credential revocation (US-ID-2/3) and factory reset.
    func reset() {
        defaults.removeObject(forKey: key)
    }
}

extension Notification.Name {
    /// Posted by the Permissions tab's "re-run onboarding" link (US-SET-5);
    /// AppDelegate presents the first-run window unconditionally.
    static let rerunFirstRun = Notification.Name("SingularityRerunFirstRun")
}
