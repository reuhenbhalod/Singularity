//
//  CredentialStateChecker.swift
//  Singularity
//

import AuthenticationServices

/// The resolved state of a stored Apple ID credential.
enum AppleIDCredentialState: Equatable {
    case authorized
    case revoked
    case notFound
    case unknown
}

/// Checks whether a stored Apple ID sign-in is still valid (T-P7-04).
/// Abstracted behind a protocol so `AccountModel` can be tested without
/// AuthenticationServices, which needs a real signed-in Apple ID.
protocol AppleIDCredentialChecking: Sendable {
    func state(forUserID userID: String) async -> AppleIDCredentialState
}

/// Production checker backed by `ASAuthorizationAppleIDProvider`.
struct AppleIDCredentialChecker: AppleIDCredentialChecking {
    func state(forUserID userID: String) async -> AppleIDCredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                switch state {
                case .authorized: continuation.resume(returning: .authorized)
                case .revoked: continuation.resume(returning: .revoked)
                case .notFound: continuation.resume(returning: .notFound)
                default: continuation.resume(returning: .unknown)
                }
            }
        }
    }
}
