//
//  PlanRejection.swift
//  Singularity
//

import Foundation

/// Why `PlanValidator` refused a plan (brief §11.3 / §11.7). Each case
/// carries a `planHash` — a short fingerprint of the plan body — so a
/// rejection can be logged and correlated **without** logging the plan
/// itself (which may contain user content). The `humanMessage` is the
/// plain-English line shown in the session log.
enum PlanRejection: Error, Equatable {
    /// A web URL whose host isn't on the allowlist (or wasn't https / had
    /// userinfo). The bare host is safe to log; the full URL is not.
    case urlDenied(host: String, planHash: String)

    /// The plan contained an action the validator will never run (e.g.
    /// raw `web_evaluate` JavaScript). Fail-closed.
    case disallowedAction(kind: String, planHash: String)

    /// The fingerprint of the rejected plan (safe to log).
    var planHash: String {
        switch self {
        case .urlDenied(_, let hash), .disallowedAction(_, let hash):
            return hash
        }
    }

    /// A low-cardinality, content-free label safe to log at `.public`.
    var reasonLabel: String {
        switch self {
        case .urlDenied: return "url_denied"
        case .disallowedAction: return "disallowed_action"
        }
    }

    /// The plain-English line shown to the user in the session log.
    var humanMessage: String {
        switch self {
        case .urlDenied(let host, _):
            return "I can't open \(host) — it isn't on the allowed-sites list."
        case .disallowedAction(let kind, _):
            return "That request needed an action I won't run (\(kind))."
        }
    }
}
