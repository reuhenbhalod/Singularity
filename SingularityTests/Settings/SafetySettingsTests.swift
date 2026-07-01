//
//  SafetySettingsTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct SafetySettingsTests {
    /// T-P5-19: safety settings have the spec defaults.
    @Test func safetyDefaults() throws {
        let suite = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let store = SettingsStore(defaults: suite)
        #expect(store.nsfwFilterEnabled == true)
        #expect(store.touchIDGraceSeconds == 30)
        #expect(store.panicPhrase == "abort")
    }

    /// Safety settings persist across instances.
    @Test func safetySettingsPersist() throws {
        let name = "test-\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: name))
        defer { suite.removePersistentDomain(forName: name) }

        let store = SettingsStore(defaults: suite)
        store.nsfwFilterEnabled = false
        store.panicPhrase = "stop"
        store.touchIDGraceSeconds = 60

        let reloaded = SettingsStore(defaults: suite)
        #expect(reloaded.nsfwFilterEnabled == false)
        #expect(reloaded.panicPhrase == "stop")
        #expect(reloaded.touchIDGraceSeconds == 60)
    }
}
