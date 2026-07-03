//
//  AccountModel.swift
//  Singularity
//

import AuthenticationServices
import Observation

/// Observable account state for the Account settings tab — the current
/// identity plus sign-in/out, backed by an `IdentityStore`.
@MainActor
@Observable
final class AccountModel {
    private(set) var identity: IdentityRecord?

    @ObservationIgnored private let store: any IdentityStore
    @ObservationIgnored private let firstRun: FirstRunFlow

    init(store: any IdentityStore = KeychainIdentityStore(), firstRun: FirstRunFlow = FirstRunFlow()) {
        self.store = store
        self.firstRun = firstRun
        self.identity = store.read()
    }

    var isSignedIn: Bool { identity != nil }

    func signIn(_ record: IdentityRecord) {
        store.write(record)
        identity = record
    }

    /// Extracts an `IdentityRecord` from a Sign in with Apple result and
    /// signs in. A failure (e.g. the capability isn't set up yet) is a
    /// no-op — the sign-in button stays. Shared by the Account tab and the
    /// first-run flow.
    func signIn(from result: Result<ASAuthorization, any Error>) {
        guard case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else { return }
        let name =
            [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        signIn(
            IdentityRecord(
                user: credential.user,
                displayName: name.isEmpty ? nil : name,
                email: credential.email))
    }

    func signOut() {
        store.clear()
        identity = nil
        // Re-present the first-run identity step on next launch (US-ID-3).
        firstRun.reset()
    }

    /// Re-validates the stored Apple ID at launch (T-P7-04): if Apple
    /// reports the credential revoked or gone, sign out locally so the UI
    /// doesn't show a stale identity. An authorized/unknown result is left
    /// alone (a transient failure shouldn't log the user out).
    func refreshCredentialState(using checker: any AppleIDCredentialChecking = AppleIDCredentialChecker()) async {
        guard let userID = identity?.user else { return }
        switch await checker.state(forUserID: userID) {
        case .revoked, .notFound:
            signOut()
        case .authorized, .unknown:
            break
        }
    }
}
