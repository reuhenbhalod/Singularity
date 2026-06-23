//
//  ExecutorRouter.swift
//  Singularity
//

import Foundation
import os

/// Phase-1 executor: dispatches a `ValidatedPlan`'s steps. It only
/// understands the hero flow — open a YouTube web pane, then play the
/// newest video — and rejects anything else with `ExecutorError`.
///
/// T-P3-02 replaces this with the general lane waterfall
/// (`ExecutorLane` + first-match-wins). The web side effects go through
/// `WebPaneDriving` so the orchestration is testable without a live
/// `WKWebView`.
///
/// Accepts only `ValidatedPlan` — never `RawPlan` — so an unvalidated
/// plan cannot reach execution (the type-level gate of brief §11.3).
@MainActor
final class ExecutorRouter {
    private let compositor: CompositorStore
    private let adapter: YouTubeAdapter
    private let driver: any WebPaneDriving
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "executor")

    init(
        compositor: CompositorStore,
        adapter: YouTubeAdapter = YouTubeAdapter(),
        driver: (any WebPaneDriving)? = nil
    ) {
        self.compositor = compositor
        self.adapter = adapter
        // Default constructed here (not as a default argument) because
        // LiveWebPaneDriver's init is @MainActor-isolated.
        self.driver = driver ?? LiveWebPaneDriver()
    }

    /// Executes the plan and returns a short, user-facing summary of the
    /// last meaningful action (the pipeline logs it).
    @discardableResult
    func dispatch(_ plan: ValidatedPlan) async throws -> String {
        var currentPane: WebPaneController?
        var currentChannel: String?
        var summary = "done"

        for step in plan.steps {
            switch step.action {
            case .webNavigate(let url):
                let controller = WebPaneController(adapter: adapter)
                compositor.add(Pane(title: url.host ?? "web", kind: .web(controller)))
                currentChannel = Self.youTubeChannelHandle(from: url)
                try await driver.navigate(controller, to: url)
                currentPane = controller
                summary = "opened \(url.host ?? "page")"

            case .runScript(let adapterName, let hook):
                guard adapterName == "youtube", hook == "play_newest" else {
                    throw ExecutorError.unsupportedStep
                }
                guard let controller = currentPane else {
                    throw ExecutorError.missingPane
                }
                summary = await playNewest(channel: currentChannel, in: controller)

            case .openURL, .webEvaluate:
                // Not part of the Phase-1 hero flow; Phase 3 adds lanes.
                throw ExecutorError.unsupportedStep
            }
        }

        return summary
    }

    /// Finds the newest video on the channel page (whose result the hook
    /// returns as a watch URL), navigates the pane to it, and nudges
    /// playback. Each stage degrades into a precise status string rather
    /// than throwing, so the log pinpoints where the hero flow stalls.
    private func playNewest(channel: String?, in controller: WebPaneController) async -> String {
        let channel = channel ?? "the channel"

        // Find the newest video's watch URL. Best-effort: a miss yields a
        // status line, not a crash.
        let found =
            (try? await driver.runHook(
                controller, javaScript: adapter.playNewestForChannel(channel))) as? String
        guard let href = found, !href.isEmpty, let videoURL = URL(string: href) else {
            return "couldn't find a video on \(channel)'s page"
        }

        // Open the video. A failure here is the actionable one (the watch
        // page didn't load), so it gets its own status.
        do {
            try await driver.navigate(controller, to: videoURL)
        } catch {
            logger.error("opening video failed: \(String(describing: error), privacy: .public)")
            return "found the newest video but couldn't open it"
        }

        // Watch pages load paused; nudge playback. Best-effort — the
        // video is already up regardless.
        let played =
            (try? await driver.runHook(
                controller, javaScript: adapter.playCurrentVideo())) as? String
        return played == "playing"
            ? "playing newest \(channel) video"
            : "opened newest \(channel) video"
    }

    /// Pulls the channel handle from a YouTube `/@Handle/...` URL —
    /// e.g. `https://www.youtube.com/@MrBeast/videos` -> `"MrBeast"`.
    /// The navigate step carries the channel; `play_newest` reuses it.
    static func youTubeChannelHandle(from url: URL) -> String? {
        for component in url.pathComponents where component.hasPrefix("@") {
            return String(component.dropFirst())
        }
        return nil
    }
}
