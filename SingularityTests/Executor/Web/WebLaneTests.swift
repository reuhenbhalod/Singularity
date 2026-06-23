//
//  WebLaneTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Records web side effects in order; returns a watch URL for the
/// find hook and "playing" for the play hook.
@MainActor
private final class FakeWebPaneDriver: WebPaneDriving {
    enum Event: Equatable {
        case navigate(URL)
        case runHook(String)
    }

    private(set) var events: [Event] = []
    var hookResult: Any? = "https://www.youtube.com/watch?v=TEST123"

    func navigate(_ controller: WebPaneController, to url: URL) async throws {
        events.append(.navigate(url))
    }

    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        events.append(.runHook(javaScript))
        if javaScript.contains(".play()") { return "playing" }
        return hookResult
    }
}

@MainActor
struct WebLaneTests {
    private func channelURL() throws -> URL {
        try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
    }

    /// Handles web_navigate and the youtube/play_newest hook only.
    @Test func handlesWebNavigateAndYouTubePlayNewest() throws {
        let lane = WebLane(compositor: CompositorStore(), driver: FakeWebPaneDriver())
        let url = try #require(URL(string: "https://example.com"))

        #expect(lane.canHandle(PlanStep(action: .webNavigate(url))))
        #expect(lane.canHandle(PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest"))))
        #expect(!lane.canHandle(PlanStep(action: .runScript(adapter: "youtube", hook: "subscribe"))))
        #expect(!lane.canHandle(PlanStep(action: .openURL(url))))
    }

    /// T-P3-02 regression: navigate opens a pane, then play_newest
    /// finds the video, opens it, and starts playback.
    @Test func navigateThenPlayNewest() async throws {
        let compositor = CompositorStore()
        let driver = FakeWebPaneDriver()
        let lane = WebLane(compositor: compositor, driver: driver)

        let nav = try await lane.execute(PlanStep(action: .webNavigate(channelURL())))
        #expect(nav == .handled(summary: "opened www.youtube.com"))
        #expect(compositor.panes.count == 1)

        let play = try await lane.execute(
            PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest")))
        #expect(play == .handled(summary: "playing newest MrBeast video"))
        // navigate(channel) -> find hook -> navigate(watch) -> play hook
        #expect(driver.events.count == 4)
    }

    /// No video found -> a status, not a crash.
    @Test func reportsWhenNoVideoFound() async throws {
        let driver = FakeWebPaneDriver()
        driver.hookResult = ""
        let lane = WebLane(compositor: CompositorStore(), driver: driver)

        _ = try await lane.execute(PlanStep(action: .webNavigate(channelURL())))
        let result = try await lane.execute(
            PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest")))

        #expect(result == .handled(summary: "couldn't find a video on MrBeast's page"))
    }

    /// play_newest with no open pane degrades gracefully.
    @Test func playWithoutOpenPaneReportsGracefully() async throws {
        let lane = WebLane(compositor: CompositorStore(), driver: FakeWebPaneDriver())

        let result = try await lane.execute(
            PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest")))

        #expect(result == .handled(summary: "couldn't play — no page is open"))
    }

    /// Channel handle is pulled from the `/@Handle/...` path.
    @Test func extractsChannelHandle() throws {
        #expect(WebLane.youTubeChannelHandle(from: try channelURL()) == "MrBeast")
        let feed = try #require(URL(string: "https://www.youtube.com/feed"))
        #expect(WebLane.youTubeChannelHandle(from: feed) == nil)
    }
}
