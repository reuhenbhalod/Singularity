//
//  AuthorizationGateTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct AuthorizationGateTests {
    /// T-P5-09: read/reversible actions authorize without a prompt.
    @Test func lowRiskPassesWithoutPrompt() async {
        var prompted = false
        let gate = DeviceAuthorizationGate(evaluate: { _ in prompted = true; return true })

        #expect(await gate.authorize(action: "open", risk: .read) == .authorized)
        #expect(await gate.authorize(action: "play", risk: .reversible) == .authorized)
        #expect(!prompted)
    }

    /// A destructive action prompts; success authorizes, failure denies.
    @Test func destructivePromptsAndReflectsResult() async {
        let ok = DeviceAuthorizationGate(evaluate: { _ in true })
        #expect(await ok.authorize(action: "delete", risk: .destructive) == .authorized)

        let no = DeviceAuthorizationGate(evaluate: { _ in false })
        #expect(await no.authorize(action: "delete", risk: .destructive) == .denied)
    }

    /// A success is cached for the grace window, then re-prompts.
    @Test func graceCachesThenReprompts() async {
        var prompts = 0
        var clock = Date(timeIntervalSince1970: 0)
        let gate = DeviceAuthorizationGate(
            graceSeconds: 30, now: { clock }, evaluate: { _ in prompts += 1; return true })

        _ = await gate.authorize(action: "a", risk: .spend)  // prompts -> 1
        clock = Date(timeIntervalSince1970: 10)
        _ = await gate.authorize(action: "b", risk: .spend)  // within grace, no prompt
        #expect(prompts == 1)

        clock = Date(timeIntervalSince1970: 100)
        _ = await gate.authorize(action: "c", risk: .spend)  // grace expired -> prompts 2
        #expect(prompts == 2)
    }
}
