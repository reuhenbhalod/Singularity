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
}
