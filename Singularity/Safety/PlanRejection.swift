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

    /// A file path that escapes the allowed scope (outside home, a
    /// protected subtree, or a symlink/`..` escape).
    case filePathEscape(planHash: String)

    /// A shell command that hit a static safety rule.
    case shellRuleViolation(rule: String, planHash: String)

    /// A shell/file argument echoing recently-read untrusted content —
    /// an indirect-injection / read-then-act attempt.
    case crossContextContamination(planHash: String)

    /// The fingerprint of the rejected plan (safe to log).
    var planHash: String {
        switch self {
        case .urlDenied(_, let hash), .disallowedAction(_, let hash),
            .shellRuleViolation(_, let hash):
            return hash
        case .filePathEscape(let hash), .crossContextContamination(let hash):
            return hash
        }
    }

    /// A low-cardinality, content-free label safe to log at `.public`.
    var reasonLabel: String {
        switch self {
        case .urlDenied: return "url_denied"
        case .disallowedAction: return "disallowed_action"
        case .filePathEscape: return "file_path_escape"
        case .shellRuleViolation(let rule, _): return "shell_\(rule)"
        case .crossContextContamination: return "cross_context_contamination"
        }
    }

    /// The plain-English line shown to the user in the session log.
    var humanMessage: String {
        switch self {
        case .urlDenied(let host, _):
            return "I can't open \(host) — it isn't on the allowed-sites list."
        case .disallowedAction(let kind, _):
            return "That request needed an action I won't run (\(kind))."
        case .filePathEscape:
            return "I can only touch files inside your home folder, and not protected ones."
        case .shellRuleViolation(let rule, _):
            return "I won't run that command — it hit a safety rule (\(rule))."
        case .crossContextContamination:
            return "That looked like it was trying to feed something I just read into a command — blocked."
        }
    }
}
