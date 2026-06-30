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
    private let spotify = SpotifyWebAdapter()  // supplies the play_track hook JS
    private var currentPane: WebPaneController?
    private var currentChannel: String?
    /// The data-store id of the current pane's adapter — used to tell
    /// "same site as what's open" from "a different site", which drives
    /// the reuse-vs-new-pane decision.
    private var currentAdapterID: UUID?
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
            return (adapterName == "youtube" && hook == "play_newest")
                || (adapterName == "spotify" && hook == "play_track")
        case .webEvaluate, .axAction:
            return false
        }
    }

    func diagnose(_ step: PlanStep) -> String? {
        switch step.action {
        case .webNavigate(let url), .openURL(let url):
            // An https site we have no adapter for.
            guard url.scheme?.lowercased() == "https", let host = url.host else { return nil }
            if adapter(for: url) == nil {
                return "I can't drive \(host) yet — so far I can only use YouTube, Gmail, "
                    + "and Spotify on the web."
            }
            return nil
        case .runScript(let adapterName, let hook):
            if (adapterName == "youtube" && hook == "play_newest")
                || (adapterName == "spotify" && hook == "play_track")
            {
                return nil  // handled
            }
            return "I don't have a \"\(hook)\" action for \(adapterName)."
        case .webEvaluate, .axAction:
            return nil
        }
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        switch step.action {
        case .webNavigate(let url), .openURL(let url):
            guard let adapter = adapter(for: url) else {
                return .unhandled(reason: diagnose(step) ?? "I don't have a way to do that yet.")
            }
            // Reuse the open pane when this navigation targets the same
            // site and the planner didn't ask for a new one — so "play
            // another video" replaces in place instead of opening a new
            // tab. A different site, or an explicit new_pane, opens a new
            // pane (which is when a second tile makes sense).
            if !step.newPane,
                let controller = currentPane,
                currentAdapterID == adapter.dataStoreIdentifier
            {
                currentChannel = Self.youTubeChannelHandle(from: url)
                try await driver.navigate(controller, to: url)
                return .handled(summary: "reopened \(url.host ?? "page") in the current pane")
            }
            let controller = WebPaneController(adapter: adapter)
            compositor.add(Pane(title: url.host ?? "web", kind: .web(controller)))
            currentChannel = Self.youTubeChannelHandle(from: url)
            currentAdapterID = adapter.dataStoreIdentifier
            // Register this as the current pane BEFORE awaiting the load.
            // The navigate can take seconds; if the user re-issues the
            // command while it's still loading, the next call must see a
            // current pane and reuse it — otherwise each impatient retry
            // spawns another tab (the "4 tabs of the same channel" bug).
            currentPane = controller
            try await driver.navigate(controller, to: url)
            return .handled(summary: "opened \(url.host ?? "page")")

        case .runScript(let adapterName, _):
            guard let controller = currentPane else {
                return .handled(summary: "couldn't play — no page is open")
            }
            if adapterName == "spotify" {
                return .handled(summary: await playSpotifyTrack(in: controller))
            }
            return .handled(summary: await playNewest(channel: currentChannel, in: controller))

        case .webEvaluate, .axAction:
            return .unhandled(reason: "I don't have a way to do that yet.")
        }
    }

    /// The adapter for an https URL's host, or `nil` (non-https, no
    /// host, or no adapter claims the host).
    private func adapter(for url: URL) -> (any WebAdapter)? {
        guard url.scheme?.lowercased() == "https", let host = url.host else { return nil }
        return registry.lookup(host: host)
    }

    /// Plays the newest video for the open channel pane. Fast path: the
    /// page is already the guessed `@handle/videos` grid, so find the
    /// newest video and play it. Fallback: if the guessed handle missed
    /// (no video on the page), resolve the creator through YouTube's own
    /// channel search, go to the real channel's `/videos`, and try again
    /// — so the user never has to know the exact handle. Each stage
    /// degrades into a status string rather than throwing.
    private func playNewest(channel: String?, in controller: WebPaneController) async -> String {
        let name = channel ?? "the channel"

        // Fast path: current page is the guessed channel grid.
        if let videoURL = await newestVideoURL(in: controller) {
            return await openAndPlay(videoURL, name: name, in: controller)
        }

        // Fallback: resolve the creator via search, then retry on the
        // real channel's /videos page.
        if await resolveChannelViaSearch(name: name, in: controller),
            let videoURL = await newestVideoURL(in: controller)
        {
            return await openAndPlay(videoURL, name: name, in: controller)
        }

        return "couldn't find a video for \(name)"
    }

    /// Runs the find-newest hook on whatever channel `/videos` page is
    /// loaded and returns the newest video's URL, or `nil`.
    private func newestVideoURL(in controller: WebPaneController) async -> URL? {
        let found =
            (try? await driver.runHook(
                controller, javaScript: youTube.playNewestForChannel(currentChannel ?? ""))) as? String
        guard let href = found, !href.isEmpty else { return nil }
        return URL(string: href)
    }

    /// Resolves a creator name to its real channel via YouTube's channels
    /// search and leaves the pane on that channel's `/videos`. Returns
    /// whether resolution succeeded.
    private func resolveChannelViaSearch(name: String, in controller: WebPaneController) async -> Bool {
        let term = Self.searchTerm(for: name)
        guard let searchURL = youTube.channelSearchURL(for: term) else { return false }
        do { try await driver.navigate(controller, to: searchURL) } catch { return false }

        let channelHref =
            (try? await driver.runHook(controller, javaScript: youTube.firstChannelHref())) as? String
        guard let href = channelHref, !href.isEmpty,
            let channelURL = URL(string: href),
            let videosURL = Self.channelVideosURL(from: channelURL)
        else { return false }

        do { try await driver.navigate(controller, to: videosURL) } catch { return false }
        currentChannel = Self.youTubeChannelHandle(from: videosURL) ?? name
        return true
    }

    /// Navigates the pane to a video URL and nudges playback.
    private func openAndPlay(_ videoURL: URL, name: String, in controller: WebPaneController) async
        -> String
    {
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
            ? "playing newest \(name) video"
            : "opened newest \(name) video"
    }

    /// Turns a handle-ish token into a search-friendly name by splitting
    /// camelCase (`"MarquesBrownlee"` → `"Marques Brownlee"`); leaves an
    /// already-lowercase handle (`"mkbhd"`) untouched. Gives YouTube
    /// search a natural query when the guessed handle was a squashed name.
    static func searchTerm(for handle: String) -> String {
        var out = ""
        for (index, character) in handle.enumerated() {
            if index > 0, character.isUppercase { out.append(" ") }
            out.append(character)
        }
        return out
    }

    /// Builds a channel's `/videos` URL from a channel link of either
    /// `/@handle…` or `/channel/UC…` shape (dropping any tab the link
    /// already points at, e.g. `/featured`).
    static func channelVideosURL(from url: URL) -> URL? {
        guard let host = url.host else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        if let handle = parts.first(where: { $0.hasPrefix("@") }) {
            return URL(string: "https://\(host)/\(handle)/videos")
        }
        if let index = parts.firstIndex(of: "channel"), index + 1 < parts.count {
            return URL(string: "https://\(host)/channel/\(parts[index + 1])/videos")
        }
        return nil
    }

    /// Presses play on the first track of the open Spotify-web search
    /// page (the song the user named). Degrades to a status string.
    private func playSpotifyTrack(in controller: WebPaneController) async -> String {
        let result =
            (try? await driver.runHook(controller, javaScript: spotify.playFirstTrack())) as? String
        return result == "playing"
            ? "playing the track on Spotify"
            : "couldn't find that track on Spotify"
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
