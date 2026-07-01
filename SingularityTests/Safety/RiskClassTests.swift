//
//  RiskClassTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct RiskClassTests {
    /// T-P5-01: risk classes order from least to most consequential, so a
    /// gate can ask "is this at least Destructive?" and an override can
    /// only raise.
    @Test func ordersByConsequence() {
        #expect(RiskClass.read < .reversible)
        #expect(RiskClass.reversible < .destructive)
        #expect(RiskClass.destructive < .spend)
        #expect(max(RiskClass.read, .destructive) == .destructive)
    }

    /// T-P5-01: the default action→risk mapping. Today's actions only
    /// read or reversibly drive an app.
    @Test func mapsActionsToDefaults() throws {
        let url = try #require(URL(string: "https://www.youtube.com/"))
        #expect(RiskClass.default(for: .openURL(url)) == .read)
        #expect(RiskClass.default(for: .webNavigate(url)) == .read)
        #expect(RiskClass.default(for: .runScript(adapter: "youtube", hook: "play_newest")) == .reversible)
        #expect(RiskClass.default(for: .axAction(adapter: "spotify", hook: "playpause")) == .reversible)
    }
}
