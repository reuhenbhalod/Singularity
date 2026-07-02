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

    // MARK: - Safety (Phase 5)

    /// NSFW URL filter, on by default. Turning it off only skips the NSFW
    /// check; it never widens the allowlist (US-NSFW-1).
    var nsfwFilterEnabled: Bool {
        didSet { defaults.set(nsfwFilterEnabled, forKey: Keys.nsfwFilterEnabled) }
    }

    /// Seconds a successful Touch ID authorization is cached (0–300).
    var touchIDGraceSeconds: Int {
        didSet { defaults.set(touchIDGraceSeconds, forKey: Keys.touchIDGraceSeconds) }
    }

    /// The phrase that hard-stops an in-flight command (default `abort`).
    var panicPhrase: String {
        didSet { defaults.set(panicPhrase, forKey: Keys.panicPhrase) }
    }

    // MARK: - General (Phase 7)

    /// Appearance: "system", "light", or "dark".
    var appearanceID: String {
        didSet { defaults.set(appearanceID, forKey: Keys.appearanceID) }
    }

    /// Summon-hotkey preset id (see `HotkeyPreset`).
    var summonHotkeyID: String {
        didSet { defaults.set(summonHotkeyID, forKey: Keys.summonHotkeyID) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? Defaults.ollamaBaseURL
        self.plannerModel = defaults.string(forKey: Keys.plannerModel) ?? Defaults.plannerModel
        self.plannerTimeoutSec =
            defaults.object(forKey: Keys.plannerTimeoutSec) as? Int ?? Defaults.plannerTimeoutSec
        self.nsfwFilterEnabled =
            defaults.object(forKey: Keys.nsfwFilterEnabled) as? Bool ?? Defaults.nsfwFilterEnabled
        self.touchIDGraceSeconds =
            defaults.object(forKey: Keys.touchIDGraceSeconds) as? Int ?? Defaults.touchIDGraceSeconds
        self.panicPhrase = defaults.string(forKey: Keys.panicPhrase) ?? Defaults.panicPhrase
        self.appearanceID = defaults.string(forKey: Keys.appearanceID) ?? Defaults.appearanceID
        self.summonHotkeyID = defaults.string(forKey: Keys.summonHotkeyID) ?? Defaults.summonHotkeyID
    }

    /// Restores every setting to its default and clears the backing keys
    /// (used by the Advanced tab's factory reset, T-P7-22).
    func resetToDefaults() {
        ollamaBaseURL = Defaults.ollamaBaseURL
        plannerModel = Defaults.plannerModel
        plannerTimeoutSec = Defaults.plannerTimeoutSec
        nsfwFilterEnabled = Defaults.nsfwFilterEnabled
        touchIDGraceSeconds = Defaults.touchIDGraceSeconds
        panicPhrase = Defaults.panicPhrase
        appearanceID = Defaults.appearanceID
        summonHotkeyID = Defaults.summonHotkeyID
    }

    enum Defaults {
        static let ollamaBaseURL = "http://localhost:11434"
        static let plannerModel = "qwen2.5-coder:7b-instruct-q4_K_M"
        static let plannerTimeoutSec = 30
        static let nsfwFilterEnabled = true
        static let touchIDGraceSeconds = 30
        static let panicPhrase = "abort"
        static let appearanceID = "system"
        static let summonHotkeyID = "opt-space"
    }

    private enum Keys {
        static let ollamaBaseURL = "planner.ollamaBaseURL"
        static let plannerModel = "planner.model"
        static let plannerTimeoutSec = "planner.timeoutSec"
        static let nsfwFilterEnabled = "safety.nsfwFilterEnabled"
        static let touchIDGraceSeconds = "safety.touchIDGraceSeconds"
        static let panicPhrase = "safety.panicPhrase"
        static let appearanceID = "general.appearance"
        static let summonHotkeyID = "general.summonHotkey"
    }
}
