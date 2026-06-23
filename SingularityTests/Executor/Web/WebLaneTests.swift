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

    /// Handles website navigations for known hosts and the
    /// youtube/play_newest hook; declines unknown hosts and unknown
    /// hooks.
    @Test func handlesKnownHostsAndPlayNewest() throws {
        let lane = WebLane(compositor: CompositorStore(), driver: FakeWebPaneDriver())
        let known = try #require(URL(string: "https://www.youtube.com/feed"))
        let unknown = try #require(URL(string: "https://example.com"))

        #expect(lane.canHandle(PlanStep(action: .webNavigate(known))))
        #expect(lane.canHandle(PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest"))))
        // Unknown host -> no adapter -> not handled.
        #expect(!lane.canHandle(PlanStep(action: .webNavigate(unknown))))
        #expect(!lane.canHandle(PlanStep(action: .runScript(adapter: "youtube", hook: "subscribe"))))
    }

    /// T-P3-10: an https open_url for a known host is handled — the lane
    /// picks the adapter (YouTube), builds a pane, and tiles it.
    @Test func handlesHTTPSOpenURLViaRegistry() async throws {
        let compositor = CompositorStore()
        let lane = WebLane(compositor: compositor, driver: FakeWebPaneDriver())
        let url = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        let step = PlanStep(action: .openURL(url))

        #expect(lane.canHandle(step))
        let result = try await lane.execute(step)
        #expect(result == .handled(summary: "opened www.youtube.com"))
        #expect(compositor.panes.count == 1)
        guard case .web = compositor.panes[0].kind else {
            Issue.record("expected a web pane")
            return
        }
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
