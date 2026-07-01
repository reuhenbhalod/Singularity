//
//  PlanValidatorTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct PlanValidatorTests {
    private func raw(_ actions: [Action]) -> RawPlan {
        RawPlan(steps: actions.map { PlanStep(action: $0) })
    }

    /// T-P5-03: an allowlisted https plan validates into a ValidatedPlan
    /// (which only PlanValidator can produce).
    @Test func allowsAllowlistedHTTPS() throws {
        let url = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        guard case .success(let plan) = PlanValidator().validate(raw([.webNavigate(url)])) else {
            Issue.record("expected success")
            return
        }
        #expect(plan.steps.count == 1)
    }

    /// T-P5-03: an off-allowlist host is rejected, naming the host.
    @Test func rejectsOffAllowlistHost() throws {
        let url = try #require(URL(string: "https://evil.example.com/"))
        guard case .failure(let rejection) = PlanValidator().validate(raw([.webNavigate(url)])) else {
            Issue.record("expected failure")
            return
        }
        #expect(rejection == .urlDenied(host: "evil.example.com", planHash: rejection.planHash))
        #expect(rejection.reasonLabel == "url_denied")
        #expect(rejection.humanMessage.contains("evil.example.com"))
    }

    /// Non-https web URLs are rejected.
    @Test func rejectsHTTP() throws {
        let url = try #require(URL(string: "http://www.youtube.com/"))
        guard case .failure = PlanValidator().validate(raw([.webNavigate(url)])) else {
            Issue.record("expected failure")
            return
        }
    }

    /// T-P5-04: raw web_evaluate JavaScript fails closed.
    @Test func failsClosedOnWebEvaluate() {
        guard case .failure(let rejection) =
            PlanValidator().validate(raw([.webEvaluate(script: "alert(1)")]))
        else {
            Issue.record("expected failure")
            return
        }
        #expect(rejection.reasonLabel == "disallowed_action")
    }

    /// A custom-scheme open_url (spotify:) is allowed — the URL-scheme
    /// lane launches it; it isn't a web navigation through the allowlist.
    @Test func allowsCustomSchemeOpenURL() throws {
        let url = try #require(URL(string: "spotify:track:abc"))
        guard case .success = PlanValidator().validate(raw([.openURL(url)])) else {
            Issue.record("expected success")
            return
        }
    }

    /// Adapter hooks (run_script / ax_action) carry no URL and validate.
    @Test func allowsAdapterHooks() {
        let result = PlanValidator().validate(
            raw([
                .runScript(adapter: "youtube", hook: "play_newest"),
                .axAction(adapter: "spotify", hook: "playpause"),
            ]))
        guard case .success = result else {
            Issue.record("expected success")
            return
        }
    }

    /// The plan fingerprint is stable and non-empty (and content-free).
    @Test func planHashIsStable() throws {
        let url = try #require(URL(string: "https://www.youtube.com/"))
        let first = PlanValidator.planHash(raw([.webNavigate(url)]))
        let second = PlanValidator.planHash(raw([.webNavigate(url)]))
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    /// SafetyVerdict stub still exists (Phase 5 fills in .deny etc.).
    @Test func safetyVerdictAllowExists() {
        #expect(SafetyVerdict.allow == .allow)
    }
}
