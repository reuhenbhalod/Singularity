//
//  SafetyLog.swift
//  Singularity
//

import Foundation
import os

/// Structured logging for the safety pipeline (research brief §11.7).
/// Phase 3 adds the `urlDenied` call site; Phase 5 fills in the rest
/// (input blocked, plan rejected, auth failed, panic cancelled, …).
///
/// Logs go to OSLog under the app's subsystem and the `safety`
/// category. Low-cardinality identifiers (the host) are `.public` so
/// they're filterable; anything potentially sensitive (the full URL)
/// is `.private`. Inspect with:
///
///     log show --predicate 'subsystem == "com.reuhenbhalod.Singularity"
///       AND category == "safety"' --last 5m
enum SafetyLog {
    static let subsystem = "com.reuhenbhalod.Singularity"
    static let category = "safety"

    private static let logger = Logger(subsystem: subsystem, category: category)

    /// A web pane was refused navigation to `host` (the full `url` is
    /// logged privately).
    static func urlDenied(host: String, url: URL) {
        logger.warning(
            "url denied host=\(host, privacy: .public) url=\(url.absoluteString, privacy: .private)")
    }

    /// A download was refused (the filename is logged privately).
    static func downloadDenied(filename: String) {
        logger.warning("download denied file=\(filename, privacy: .private)")
    }

    /// The `PlanValidator` rejected a plan. The reason label and plan
    /// fingerprint are content-free and logged `.public`; the plan body
    /// is never logged (brief §11.7).
    static func planRejected(reason: String, planHash: String) {
        logger.warning(
            "plan rejected reason=\(reason, privacy: .public) hash=\(planHash, privacy: .public)")
    }

    /// Input was dropped at the boundary (the category is safe to log;
    /// the raw input is never logged).
    static func inputBlocked(reason: String) {
        logger.warning("input blocked reason=\(reason, privacy: .public)")
    }

    /// A device-authentication prompt failed or was cancelled (the action
    /// label is low-cardinality; no user content).
    static func authFailed(action: String) {
        logger.warning("auth failed action=\(action, privacy: .public)")
    }

    /// The instruction-detection heuristic fired on untrusted content
    /// (only the source label and matched pattern are logged, not the
    /// content).
    static func untrustedHeuristicFired(source: String, pattern: String) {
        logger.warning(
            "untrusted heuristic source=\(source, privacy: .public) pattern=\(pattern, privacy: .public)"
        )
    }

    /// An in-flight command was hard-stopped by the panic phrase / double-Esc.
    static func panicCancelled() {
        logger.notice("panic cancelled")
    }
}
