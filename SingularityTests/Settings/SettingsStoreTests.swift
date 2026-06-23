//
//  SettingsStoreTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct SettingsStoreTests {
    /// A fresh, isolated UserDefaults suite per test.
    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)"))
    }

    /// T-P2-10: exposes the documented defaults.
    @Test func exposesExpectedDefaults() throws {
        let store = SettingsStore(defaults: try isolatedDefaults())

        #expect(store.ollamaBaseURL == "http://localhost:11434")
        #expect(store.plannerModel == "qwen2.5-coder:7b-instruct-q4_K_M")
        #expect(store.plannerTimeoutSec == 30)
    }

    /// T-P2-10: changes persist and survive a "restart" (a new store
    /// over the same backing defaults).
    @Test func changesPersistAcrossInstances() throws {
        let defaults = try isolatedDefaults()

        let store = SettingsStore(defaults: defaults)
        store.ollamaBaseURL = "http://example.local:1234"
        store.plannerModel = "qwen2.5-coder:14b-instruct-q4_K_M"
        store.plannerTimeoutSec = 60

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.ollamaBaseURL == "http://example.local:1234")
        #expect(reloaded.plannerModel == "qwen2.5-coder:14b-instruct-q4_K_M")
        #expect(reloaded.plannerTimeoutSec == 60)
    }
}
