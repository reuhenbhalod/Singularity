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
}
