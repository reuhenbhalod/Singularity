//
//  CredentialAndFirstRunTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// A stub credential checker returning a fixed state.
private struct StubChecker: AppleIDCredentialChecking {
    let result: AppleIDCredentialState
    func state(forUserID userID: String) async -> AppleIDCredentialState { result }
}

@MainActor
struct CredentialStateTests {
    private func signedInModel() -> AccountModel {
        AccountModel(store: InMemoryIdentityStore(
            IdentityRecord(user: "u", displayName: "A", email: nil)))
    }

    /// T-P7-04: a revoked credential signs the user out at launch.
    @Test func revokedSignsOut() async {
        let model = signedInModel()
        await model.refreshCredentialState(using: StubChecker(result: .revoked))
        #expect(!model.isSignedIn)
    }

    /// A notFound credential also signs out.
    @Test func notFoundSignsOut() async {
        let model = signedInModel()
        await model.refreshCredentialState(using: StubChecker(result: .notFound))
        #expect(!model.isSignedIn)
    }

    /// An authorized (or unknown) result leaves the session intact — a
    /// transient failure must not log the user out.
    @Test func authorizedKeepsSession() async {
        let model = signedInModel()
        await model.refreshCredentialState(using: StubChecker(result: .authorized))
        #expect(model.isSignedIn)

        await model.refreshCredentialState(using: StubChecker(result: .unknown))
        #expect(model.isSignedIn)
    }

    /// Signed out → the check is a no-op (no credential to validate).
    @Test func signedOutIsNoOp() async {
        let model = AccountModel(store: InMemoryIdentityStore())
        await model.refreshCredentialState(using: StubChecker(result: .revoked))
        #expect(!model.isSignedIn)
    }
}

struct FirstRunFlowTests {
    /// T-P7-08: shows once, then not again after completion.
    @Test func showsOnceThenMarksComplete() throws {
        let defaults = try #require(UserDefaults(suiteName: "fr-flow-\(UUID().uuidString)"))
        let flow = FirstRunFlow(defaults: defaults)
        #expect(flow.shouldShow)

        flow.markComplete()
        #expect(!FirstRunFlow(defaults: defaults).shouldShow)
    }
}
