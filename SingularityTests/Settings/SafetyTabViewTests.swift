//
//  SafetyTabViewTests.swift
//  SingularityTests
//

import SwiftUI
import Testing

@testable import Singularity

@MainActor
struct SafetyTabViewTests {
    /// T-P5-19: the Safety tab instantiates and hosts cleanly.
    @Test func instantiatesAndHosts() throws {
        let suite = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let view = SafetyTabView(settings: SettingsStore(defaults: suite))
        let hosting = NSHostingView(rootView: view)
        #expect(hosting.rootView is SafetyTabView)
    }
}
