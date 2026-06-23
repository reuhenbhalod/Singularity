//
//  SettingsStore.swift
//  Singularity
//

import Foundation
import Observation

/// Observable, persisted application settings. Phase 2 holds only the
/// planner-related values so the Phase-7 Settings UI can later read and
/// write a stable store; there is no UI yet.
///
/// Each property writes through to `UserDefaults` on change (didSet is
/// not fired during `init`, so loading defaults doesn't write back).
/// The backing store is injectable so tests use an isolated suite.
@MainActor
@Observable
final class SettingsStore {
    var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: Keys.ollamaBaseURL) }
    }

    var plannerModel: String {
        didSet { defaults.set(plannerModel, forKey: Keys.plannerModel) }
    }

    var plannerTimeoutSec: Int {
        didSet { defaults.set(plannerTimeoutSec, forKey: Keys.plannerTimeoutSec) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? Defaults.ollamaBaseURL
        self.plannerModel = defaults.string(forKey: Keys.plannerModel) ?? Defaults.plannerModel
        self.plannerTimeoutSec =
            defaults.object(forKey: Keys.plannerTimeoutSec) as? Int ?? Defaults.plannerTimeoutSec
    }

    enum Defaults {
        static let ollamaBaseURL = "http://localhost:11434"
        static let plannerModel = "qwen2.5-coder:7b-instruct-q4_K_M"
        static let plannerTimeoutSec = 30
    }

    private enum Keys {
        static let ollamaBaseURL = "planner.ollamaBaseURL"
        static let plannerModel = "planner.model"
        static let plannerTimeoutSec = "planner.timeoutSec"
    }
}
