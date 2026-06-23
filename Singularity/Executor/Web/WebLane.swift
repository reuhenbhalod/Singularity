//
//  WebLane.swift
//  Singularity
//

import Foundation
import os

/// Lane 2 of the executor waterfall: drives `WKWebView` panes. Handles
/// `web_navigate` (open/navigate a pane) and the YouTube `play_newest`
/// `run_script` hook, carrying the current pane between a navigate step
/// and the script step that follows it.
///
/// Phase 3 still hardwires the `YouTubeAdapter`; T-P3-10 swaps in the
/// `AdapterRegistry` so the adapter is chosen by host. Web side effects
/// go through `WebPaneDriving` so the lane is testable without WebKit.
@MainActor
final class WebLane: ExecutorLane {
    private let compositor: CompositorStore
    private let adapter: YouTubeAdapter
    private let driver: any WebPaneDriving
    private var currentPane: WebPaneController?
    private var currentChannel: String?
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "executor")

    init(
        compositor: CompositorStore,
        adapter: YouTubeAdapter = YouTubeAdapter(),
        driver: (any WebPaneDriving)? = nil
    ) {
        self.compositor = compositor
        self.adapter = adapter
        self.driver = driver ?? LiveWebPaneDriver()
    }

    func canHandle(_ step: PlanStep) -> Bool {
        switch step.action {
        case .webNavigate:
            return true
        case .runScript(let adapterName, let hook):
            return adapterName == "youtube" && hook == "play_newest"
        case .openURL, .webEvaluate:
            return false
        }
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        switch step.action {
        case .webNavigate(let url):
            let controller = WebPaneController(adapter: adapter)
            compositor.add(Pane(title: url.host ?? "web", kind: .web(controller)))
            currentChannel = Self.youTubeChannelHandle(from: url)
            try await driver.navigate(controller, to: url)
            currentPane = controller
            return .handled(summary: "opened \(url.host ?? "page")")

        case .runScript:
            guard let controller = currentPane else {
                return .handled(summary: "couldn't play — no page is open")
            }
            return .handled(summary: await playNewest(channel: currentChannel, in: controller))

        case .openURL, .webEvaluate:
            return .unhandled
        }
    }

    /// Finds the newest video on the channel page (the hook returns its
    /// watch URL), navigates the pane to it, and nudges playback. Each
    /// stage degrades into a status string rather than throwing.
    private func playNewest(channel: String?, in controller: WebPaneController) async -> String {
        let channel = channel ?? "the channel"

        let found =
            (try? await driver.runHook(
                controller, javaScript: adapter.playNewestForChannel(channel))) as? String
        guard let href = found, !href.isEmpty, let videoURL = URL(string: href) else {
            return "couldn't find a video on \(channel)'s page"
        }

        do {
            try await driver.navigate(controller, to: videoURL)
        } catch {
            logger.error("opening video failed: \(String(describing: error), privacy: .public)")
            return "found the newest video but couldn't open it"
        }

        let played =
            (try? await driver.runHook(
                controller, javaScript: adapter.playCurrentVideo())) as? String
        return played == "playing"
            ? "playing newest \(channel) video"
            : "opened newest \(channel) video"
    }

    /// Pulls the channel handle from a YouTube `/@Handle/...` URL —
    /// e.g. `https://www.youtube.com/@MrBeast/videos` -> `"MrBeast"`.
    static func youTubeChannelHandle(from url: URL) -> String? {
        for component in url.pathComponents where component.hasPrefix("@") {
            return String(component.dropFirst())
        }
        return nil
    }
}
