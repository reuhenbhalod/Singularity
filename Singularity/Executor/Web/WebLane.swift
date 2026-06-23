//
//  WebLane.swift
//  Singularity
//

import Foundation
import os

/// Lane 2 of the waterfall: drives `WKWebView` panes. Handles website
/// navigations (`web_navigate`, or `open_url` with an https URL) for any
/// host an adapter claims, and the YouTube `play_newest` hook. The pane
/// is carried between a navigate step and the script step that follows.
///
/// The adapter is chosen by host via `AdapterRegistry` (research brief
/// §4); a URL whose host has no adapter is left for another lane / the
/// "couldn't handle that" path. Web side effects go through
/// `WebPaneDriving` so the lane is testable without WebKit.
@MainActor
final class WebLane: ExecutorLane {
    private let compositor: CompositorStore
    private let registry: AdapterRegistry
    private let driver: any WebPaneDriving
    private let youTube = YouTubeAdapter()  // supplies the play_newest hook JS
    private var currentPane: WebPaneController?
    private var currentChannel: String?
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "executor")

    init(
        compositor: CompositorStore,
        registry: AdapterRegistry = AdapterRegistry(),
        driver: (any WebPaneDriving)? = nil
    ) {
        self.compositor = compositor
        self.registry = registry
        self.driver = driver ?? LiveWebPaneDriver()
    }

    func canHandle(_ step: PlanStep) -> Bool {
        switch step.action {
        case .webNavigate(let url), .openURL(let url):
            return adapter(for: url) != nil
        case .runScript(let adapterName, let hook):
            return adapterName == "youtube" && hook == "play_newest"
        case .webEvaluate:
            return false
        }
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        switch step.action {
        case .webNavigate(let url), .openURL(let url):
            guard let adapter = adapter(for: url) else { return .unhandled }
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

        case .webEvaluate:
            return .unhandled
        }
    }

    /// The adapter for an https URL's host, or `nil` (non-https, no
    /// host, or no adapter claims the host).
    private func adapter(for url: URL) -> (any WebAdapter)? {
        guard url.scheme?.lowercased() == "https", let host = url.host else { return nil }
        return registry.lookup(host: host)
    }

    /// Finds the newest video on the channel page (the hook returns its
    /// watch URL), navigates the pane to it, and nudges playback. Each
    /// stage degrades into a status string rather than throwing.
    private func playNewest(channel: String?, in controller: WebPaneController) async -> String {
        let channel = channel ?? "the channel"

        let found =
            (try? await driver.runHook(
                controller, javaScript: youTube.playNewestForChannel(channel))) as? String
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
                controller, javaScript: youTube.playCurrentVideo())) as? String
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
