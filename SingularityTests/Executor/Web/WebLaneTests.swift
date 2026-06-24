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

/// Parks the FIRST navigate on a continuation so a test can run a second
/// command "mid-load", then release it. Used to reproduce the rapid-
/// reissue race.
@MainActor
private final class GatedWebPaneDriver: WebPaneDriving {
    private(set) var navigateCount = 0
    var parked: CheckedContinuation<Void, Never>?

    func navigate(_ controller: WebPaneController, to url: URL) async throws {
        navigateCount += 1
        if navigateCount == 1 {
            await withCheckedContinuation { parked = $0 }
        }
    }

    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        ""
    }
}

/// Simulates the search-fallback path: the first find-newest hook misses
/// (bad handle), the channel-search hook returns a channel, and the
/// second find-newest hook (on the real channel) hits.
@MainActor
private final class ScriptedWebPaneDriver: WebPaneDriving {
    private(set) var navigations: [URL] = []
    var channelHref = "https://www.youtube.com/@mkbhd"
    var videoHref = "https://www.youtube.com/watch?v=REAL123"
    private var findNewestCalls = 0

    func navigate(_ controller: WebPaneController, to url: URL) async throws {
        navigations.append(url)
    }

    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        if javaScript.contains(".play()") { return "playing" }  // playCurrentVideo
        if javaScript.contains("ytd-channel-renderer") { return channelHref }  // firstChannelHref
        // playNewestForChannel: miss on the guessed page, hit after resolution.
        findNewestCalls += 1
        return findNewestCalls == 1 ? "" : videoHref
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

    /// A second same-site navigation REUSES the open pane (no new tab):
    /// "play one video then a different one" replaces in place.
    @Test func sameSiteNavigateReusesPane() async throws {
        let compositor = CompositorStore()
        let driver = FakeWebPaneDriver()
        let lane = WebLane(compositor: compositor, driver: driver)
        let first = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        let second = try #require(URL(string: "https://www.youtube.com/@veritasium/videos"))

        _ = try await lane.execute(PlanStep(action: .webNavigate(first)))
        let reuse = try await lane.execute(PlanStep(action: .webNavigate(second)))

        #expect(reuse == .handled(summary: "reopened www.youtube.com in the current pane"))
        #expect(compositor.panes.count == 1)  // reused, not a second tile
        #expect(driver.events == [.navigate(first), .navigate(second)])
    }

    /// Regression for the "4 tabs of the same channel" bug: a second
    /// command issued WHILE the first navigation is still loading must
    /// reuse the pane, not spawn another tab. The gated driver parks the
    /// first navigate so the second runs mid-load.
    @Test func rapidReissueDuringLoadReusesPane() async throws {
        let compositor = CompositorStore()
        let driver = GatedWebPaneDriver()
        let lane = WebLane(compositor: compositor, driver: driver)
        let url = try #require(URL(string: "https://www.youtube.com/@KaiCenat/videos"))

        // Start the first navigate; it parks inside the driver.
        let first = Task { try await lane.execute(PlanStep(action: .webNavigate(url))) }
        while driver.parked == nil { await Task.yield() }  // wait until mid-load

        // Re-issue while the first is still loading.
        _ = try await lane.execute(PlanStep(action: .webNavigate(url)))
        #expect(compositor.panes.count == 1)  // reused, NOT a 2nd tab

        driver.parked?.resume()
        _ = try await first.value
    }

    /// An explicit `new_pane` opens a second pane even for the same site.
    @Test func newPaneFlagOpensASecondPane() async throws {
        let compositor = CompositorStore()
        let lane = WebLane(compositor: compositor, driver: FakeWebPaneDriver())
        let first = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        let second = try #require(URL(string: "https://www.youtube.com/@veritasium/videos"))

        _ = try await lane.execute(PlanStep(action: .webNavigate(first)))
        let opened = try await lane.execute(PlanStep(action: .webNavigate(second), newPane: true))

        #expect(opened == .handled(summary: "opened www.youtube.com"))
        #expect(compositor.panes.count == 2)
    }

    /// A different site opens a new pane (a second tile makes sense).
    @Test func differentSiteOpensNewPane() async throws {
        let compositor = CompositorStore()
        let lane = WebLane(compositor: compositor, driver: FakeWebPaneDriver())
        let youtube = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        let gmail = try #require(URL(string: "https://mail.google.com/"))

        _ = try await lane.execute(PlanStep(action: .webNavigate(youtube)))
        _ = try await lane.execute(PlanStep(action: .webNavigate(gmail)))

        #expect(compositor.panes.count == 2)
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

        #expect(result == .handled(summary: "couldn't find a video for MrBeast"))
    }

    /// Search fallback: when the guessed handle page has no video, the
    /// lane resolves the creator via YouTube search, goes to the real
    /// channel's /videos, and plays the newest there.
    @Test func fallsBackToSearchWhenHandleMisses() async throws {
        let compositor = CompositorStore()
        let driver = ScriptedWebPaneDriver()
        let lane = WebLane(compositor: compositor, driver: driver)
        let badHandle = try #require(URL(string: "https://www.youtube.com/@MarquesBrownlee/videos"))

        _ = try await lane.execute(PlanStep(action: .webNavigate(badHandle)))
        let result = try await lane.execute(
            PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest")))

        #expect(result == .handled(summary: "playing newest MarquesBrownlee video"))
        // navigations: badHandle -> search -> real channel /videos -> watch
        #expect(driver.navigations.count == 4)
        #expect(driver.navigations[1].absoluteString.contains("results?search_query"))
        #expect(driver.navigations[2].absoluteString.contains("/@mkbhd/videos"))
        #expect(driver.navigations[3].absoluteString.contains("watch?v="))
    }

    @Test func searchTermSplitsCamelCaseButLeavesLowercase() {
        #expect(WebLane.searchTerm(for: "MarquesBrownlee") == "Marques Brownlee")
        #expect(WebLane.searchTerm(for: "MrBeast") == "Mr Beast")
        #expect(WebLane.searchTerm(for: "mkbhd") == "mkbhd")
    }

    @Test func channelVideosURLHandlesHandleAndChannelForms() throws {
        let handle = try #require(URL(string: "https://www.youtube.com/@mkbhd"))
        #expect(
            WebLane.channelVideosURL(from: handle)?.absoluteString
                == "https://www.youtube.com/@mkbhd/videos")
        let channel = try #require(URL(string: "https://www.youtube.com/channel/UC123/featured"))
        #expect(
            WebLane.channelVideosURL(from: channel)?.absoluteString
                == "https://www.youtube.com/channel/UC123/videos")
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
