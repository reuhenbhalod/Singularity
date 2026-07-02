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

    /// T-P5-01: today's actions all default to `.read`, so the gates stay
    /// dormant until Phase 6 introduces file/spend actions.
    @Test func mapsActionsToDefaults() throws {
        let url = try #require(URL(string: "https://www.youtube.com/"))
        #expect(RiskClass.default(for: .openURL(url)) == .read)
        #expect(RiskClass.default(for: .webNavigate(url)) == .read)
        #expect(RiskClass.default(for: .runScript(adapter: "youtube", hook: "play_newest")) == .read)
        #expect(RiskClass.default(for: .axAction(adapter: "spotify", hook: "playpause")) == .read)
    }

    /// T-P6: file ops and shell get real risk — so the gates fire.
    @Test func fileAndShellCarryRealRisk() {
        #expect(RiskClass.default(for: .fileOp(operation: "list", source: "~", destination: nil)) == .read)
        #expect(RiskClass.default(for: .fileOp(operation: "trash", source: "~/x", destination: nil)) == .reversible)
        #expect(RiskClass.default(for: .fileOp(operation: "move", source: "~/x", destination: "~/y")) == .reversible)
        #expect(RiskClass.default(for: .runShell(command: "ls", scope: "~")) == .destructive)
    }

    /// T-P5-14: escalation bumps one class, capped at `.spend`.
    @Test func escalatesOneClassCappedAtSpend() {
        #expect(RiskClass.read.escalated == .reversible)
        #expect(RiskClass.reversible.escalated == .destructive)
        #expect(RiskClass.destructive.escalated == .spend)
        #expect(RiskClass.spend.escalated == .spend)
    }
}
