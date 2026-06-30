//
//  URLSchemeLane.swift
//  Singularity
//

import Foundation

/// Lane 1 of the waterfall: opens non-web URL schemes (`spotify:`,
/// `mailto:`, `vscode:`, …) via the system handler (research brief §4).
///
/// It only claims `open_url` steps whose scheme is *not* http/https —
/// websites go to the web lane. Which custom schemes are actually
/// permitted is the validator's job in Phase 5; this lane just performs
/// the open.
@MainActor
final class URLSchemeLane: ExecutorLane {
    private let opener: any URLOpening

    init(opener: (any URLOpening)? = nil) {
        self.opener = opener ?? WorkspaceURLOpener()
    }

    func canHandle(_ step: PlanStep) -> Bool {
        guard case .openURL(let url) = step.action, let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme != "http" && scheme != "https"
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        guard case .openURL(let url) = step.action else {
            return .unhandled(reason: "I don't have a way to do that yet.")
        }
        let opened = opener.open(url)
        let label = url.scheme.map { "\($0): link" } ?? "link"
        return .handled(summary: opened ? "opened \(label)" : "couldn't open \(label)")
    }
}
