//
//  AuthorizationGate.swift
//  Singularity
//

import Foundation
import LocalAuthentication

/// The outcome of a Touch ID / passcode gate.
enum AuthorizationResult: Equatable {
    case authorized
    case denied
}

/// Gates a mutating action behind device authentication when its risk is
/// high enough (brief §11.2). Read/reversible actions pass without a
/// prompt; destructive/spend require Touch ID (or passcode), with a short
/// grace window so a burst of risky steps doesn't prompt repeatedly.
protocol AuthorizationGate {
    func authorize(action: String, risk: RiskClass) async -> AuthorizationResult
}

/// Production gate backed by `LAContext.evaluatePolicy`. The evaluation
/// closure is injectable so the gating logic (thresholds, grace cache) is
/// unit-testable without real biometrics.
@MainActor
final class DeviceAuthorizationGate: AuthorizationGate {
    /// Lowest risk that requires authentication.
    static let threshold: RiskClass = .destructive

    private let graceSeconds: TimeInterval
    private let now: () -> Date
    private let evaluate: (String) async -> Bool
    private var lastAuthorized: Date?

    init(
        graceSeconds: TimeInterval = 30,
        now: @escaping () -> Date = Date.init,
        evaluate: ((String) async -> Bool)? = nil
    ) {
        self.graceSeconds = graceSeconds
        self.now = now
        self.evaluate =
            evaluate
            ?? { reason in
                await withCheckedContinuation { continuation in
                    let context = LAContext()
                    context.evaluatePolicy(
                        .deviceOwnerAuthentication, localizedReason: reason
                    ) { success, _ in
                        continuation.resume(returning: success)
                    }
                }
            }
    }

    func authorize(action: String, risk: RiskClass) async -> AuthorizationResult {
        guard risk >= Self.threshold else { return .authorized }
        if let last = lastAuthorized, now().timeIntervalSince(last) < graceSeconds {
            return .authorized
        }
        let ok = await evaluate("Authorize: \(action)")
        if ok {
            lastAuthorized = now()
            return .authorized
        }
        SafetyLog.authFailed(action: action)
        return .denied
    }

    /// Clears the grace cache — called when the shell is dismissed so a
    /// fresh session always re-prompts.
    func clearGrace() {
        lastAuthorized = nil
    }
}
