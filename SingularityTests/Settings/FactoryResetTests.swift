//
//  FactoryResetTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct FactoryResetTests {
    /// T-P7-22: a factory reset restores settings, clears the identity,
    /// and removes the routines file.
    @Test func resetClearsAllLocalState() async throws {
        let defaults = try #require(UserDefaults(suiteName: "fr-\(UUID().uuidString)"))
        let settings = SettingsStore(defaults: defaults)
        settings.nsfwFilterEnabled = false
        settings.plannerModel = "custom-model"

        let identity = InMemoryIdentityStore(
            IdentityRecord(user: "u", displayName: "A", email: nil))

        let routinesURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fr-\(UUID().uuidString).json")
        let routines = RoutineStore(url: routinesURL)
        try await routines.upsert(
            Routine(name: "x", steps: ["a"], createdAt: Date(), updatedAt: Date()))
        #expect(FileManager.default.fileExists(atPath: routinesURL.path))

        let frDefaults = try #require(UserDefaults(suiteName: "fr-flow-\(UUID().uuidString)"))
        let firstRun = FirstRunFlow(defaults: frDefaults)
        firstRun.markComplete()

        // clearWebData: false — WebKit data-store enumeration isn't
        // meaningful in the unit-test host and would touch real state.
        await FactoryReset.run(
            settings: settings, identityStore: identity, routinesURL: routinesURL,
            firstRun: firstRun, clearWebData: false)

        #expect(settings.nsfwFilterEnabled == SettingsStore.Defaults.nsfwFilterEnabled)
        #expect(settings.plannerModel == SettingsStore.Defaults.plannerModel)
        #expect(identity.read() == nil)
        #expect(!FileManager.default.fileExists(atPath: routinesURL.path))
        #expect(firstRun.shouldShow)  // re-armed for next launch
    }

    /// `resetToDefaults` alone restores every setting value.
    @Test func settingsResetRestoresDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "fr-\(UUID().uuidString)"))
        let settings = SettingsStore(defaults: defaults)
        settings.touchIDGraceSeconds = 999
        settings.panicPhrase = "stopnow"

        settings.resetToDefaults()

        #expect(settings.touchIDGraceSeconds == SettingsStore.Defaults.touchIDGraceSeconds)
        #expect(settings.panicPhrase == SettingsStore.Defaults.panicPhrase)
    }
}
