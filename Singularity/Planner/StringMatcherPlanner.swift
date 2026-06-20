//
//  StringMatcherPlanner.swift
//  Singularity
//

import Foundation

/// Phase 1 stand-in for the real planner: recognizes exactly the
/// hero command (`play mrbeast newest video`, case-insensitive,
/// whitespace-trimmed) and nothing else. T-P2 replaces this with
/// `OllamaPlanner`. The protocol contract lets the router consume
/// either interchangeably.
struct StringMatcherPlanner: PlannerProtocol {
    func plan(_ input: String) async throws -> RawPlan? {
        let normalized =
            input
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "play mrbeast newest video":
            return mrbeastNewestVideoPlan()
        default:
            return nil
        }
    }

    private func mrbeastNewestVideoPlan() -> RawPlan {
        // swiftlint:disable:next force_unwrapping
        let channelURL = URL(string: "https://www.youtube.com/@MrBeast/videos")!
        return RawPlan(steps: [
            // 1. Load the MrBeast channel page in a WKWebView pane.
            //    Router creates a pane if none exists.
            PlanStep(action: .webNavigate(channelURL)),
            // 2. Hand off to the YouTube adapter's play_newest hook
            //    (T-P1-04 owns the resilient selector logic).
            PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest")),
        ])
    }
}
