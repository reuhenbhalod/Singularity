//
//  PlanValidator.swift
//  Singularity
//

import CryptoKit
import Foundation

/// The **sole producer** of `ValidatedPlan` (brief §11.3, T-P5-05). The
/// planner emits a `RawPlan`; nothing reaches the executor until this
/// validator turns it into a `ValidatedPlan`, and the executor router
/// accepts only `ValidatedPlan`. Because `ValidatedPlan`'s initializer is
/// `fileprivate` to *this* file, no other code in the app can construct
/// one — the safety gate is enforced by the type system, not by
/// convention.
///
/// Do not move `ValidatedPlan` out of this file or expose its init: that
/// would reopen the bypass the Phase-1 `phase1Allow` shim left (now
/// removed).
///
/// Phase 5 scope here: URL allowlisting (via the shared `URLPolicy`) and
/// fail-closed rejection of actions we never run. Shell/file-path
/// validation and the cross-context taint check fold in during Phase 6.
struct PlanValidator {
    private let urlPolicy: URLPolicy

    init(urlPolicy: URLPolicy = URLPolicy()) {
        self.urlPolicy = urlPolicy
    }

    /// Validates every step, returning a `ValidatedPlan` or the first
    /// `PlanRejection`. Fails closed: anything it can't positively vouch
    /// for is rejected.
    func validate(_ raw: RawPlan) -> Result<ValidatedPlan, PlanRejection> {
        let hash = Self.planHash(raw)
        for step in raw.steps {
            switch step.action {
            case .openURL(let url), .webNavigate(let url):
                // Only web (http/https) URLs go through the allowlist;
                // custom schemes (spotify:, mailto:) are launched by the
                // URL-scheme lane and aren't web navigations.
                if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                    if case .deny = urlPolicy.evaluate(url: url) {
                        return .failure(.urlDenied(host: url.host ?? "(none)", planHash: hash))
                    }
                }
            case .runScript, .axAction:
                // Adapter + hook are validated at execution time by the
                // lane's `canHandle`; there's no free-form payload here.
                continue
            case .webEvaluate:
                // Raw JavaScript is never trusted (and the planner's
                // schema can't even emit it). Fail closed.
                return .failure(.disallowedAction(kind: "web_evaluate", planHash: hash))
            }
        }
        return .success(ValidatedPlan(steps: raw.steps))
    }

    /// A short, content-free fingerprint of the plan body, for logging a
    /// rejection without logging the plan itself.
    static func planHash(_ raw: RawPlan) -> String {
        guard let data = try? JSONEncoder().encode(raw) else { return "unknown" }
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

/// The only plan type the executor accepts. Its initializer is
/// `fileprivate`, so `PlanValidator` (above, same file) is the one and
/// only thing that can create one. This is the type-level handoff the
/// whole safety story depends on (brief §11.3).
struct ValidatedPlan: Equatable {
    let steps: [PlanStep]

    fileprivate init(steps: [PlanStep]) {
        self.steps = steps
    }
}
