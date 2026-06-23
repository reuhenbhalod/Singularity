//
//  ExecutorRouterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Records the web side effects in order, without touching WebKit, so
/// the router's orchestration can be asserted deterministically.
@MainActor
private final class FakeWebPaneDriver: WebPaneDriving {
    enum Event: Equatable {
        case navigate(URL)
        case runHook(String)
    }

    private(set) var events: [Event] = []

    /// Canned watch URL the hook "finds", so the router proceeds to
    /// navigate to it.
    var hookResult: Any? = "https://www.youtube.com/watch?v=TEST123"

    func navigate(_ controller: WebPaneController, to url: URL) async throws {
        events.append(.navigate(url))
    }

    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        events.append(.runHook(javaScript))
        return hookResult
    }
}

@MainActor
struct ExecutorRouterTests {
    private func heroPlan() throws -> ValidatedPlan {
        let channelURL = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        return .phase1Allow(
            RawPlan(steps: [
                PlanStep(action: .webNavigate(channelURL)),
                PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest")),
            ])
        )
    }

    /// T-P1-09 acceptance: the hero plan opens a YouTube web pane and
    /// triggers `playNewestForChannel("MrBeast")` after the navigation.
    @Test func dispatchesHeroPlanOpeningYouTubePaneAndPlayingNewest() async throws {
        let compositor = CompositorStore()
        let driver = FakeWebPaneDriver()
        let router = ExecutorRouter(compositor: compositor, driver: driver)

        let summary = try await router.dispatch(heroPlan())
        #expect(summary == "playing newest MrBeast video")

        // Opens a web pane.
        #expect(compositor.panes.count == 1)
        guard case .web = compositor.panes[0].kind else {
            Issue.record("expected a web pane, got \(compositor.panes[0].kind)")
            return
        }

        // Channel nav -> play_newest hook -> navigate to the watch URL
        // the hook returned -> play hook (the router awaits each in
        // order, so in production a step runs only after the prior one).
        #expect(driver.events.count == 4)

        guard case .navigate(let channelURL) = driver.events[0] else {
            Issue.record("expected channel navigate first, got \(driver.events)")
            return
        }
        #expect(channelURL.absoluteString == "https://www.youtube.com/@MrBeast/videos")

        guard case .runHook(let findJS) = driver.events[1] else {
            Issue.record("expected play_newest hook second, got \(driver.events)")
            return
        }
        // The hook is YouTube's play_newest JS for channel "MrBeast".
        #expect(findJS.contains("\"MrBeast\""))
        #expect(findJS.contains("MutationObserver"))

        guard case .navigate(let watchURL) = driver.events[2] else {
            Issue.record("expected navigate to the watch URL third, got \(driver.events)")
            return
        }
        #expect(watchURL.absoluteString == "https://www.youtube.com/watch?v=TEST123")

        guard case .runHook(let playJS) = driver.events[3] else {
            Issue.record("expected play hook fourth, got \(driver.events)")
            return
        }
        #expect(playJS.contains(".play()"))
    }

    /// When the hook finds no video (empty href), the router reports it
    /// and does not navigate again.
    @Test func reportsWhenNoVideoFound() async throws {
        let compositor = CompositorStore()
        let driver = FakeWebPaneDriver()
        driver.hookResult = ""
        let router = ExecutorRouter(compositor: compositor, driver: driver)

        let summary = try await router.dispatch(heroPlan())

        #expect(summary == "couldn't find a video on MrBeast's page")
        // Only the initial channel navigation happened.
        #expect(driver.events.filter { if case .navigate = $0 { return true } else { return false } }.count == 1)
    }

    /// Channel handle is pulled from the `/@Handle/...` path.
    @Test func extractsChannelHandleFromVideosURL() throws {
        let videosURL = try #require(URL(string: "https://www.youtube.com/@MrBeast/videos"))
        #expect(ExecutorRouter.youTubeChannelHandle(from: videosURL) == "MrBeast")

        let feedURL = try #require(URL(string: "https://www.youtube.com/feed"))
        #expect(ExecutorRouter.youTubeChannelHandle(from: feedURL) == nil)
    }

    /// A `play_newest` step with no preceding navigation has no pane to
    /// run against.
    @Test func runScriptBeforeNavigateThrowsMissingPane() async throws {
        let router = ExecutorRouter(compositor: CompositorStore(), driver: FakeWebPaneDriver())
        let plan = ValidatedPlan.phase1Allow(
            RawPlan(steps: [PlanStep(action: .runScript(adapter: "youtube", hook: "play_newest"))])
        )

        await #expect(throws: ExecutorError.missingPane) {
            try await router.dispatch(plan)
        }
    }

    /// Phase 1 only routes the hero flow; an `open_url` step is rejected.
    @Test func openURLStepIsUnsupportedInPhase1() async throws {
        let router = ExecutorRouter(compositor: CompositorStore(), driver: FakeWebPaneDriver())
        let url = try #require(URL(string: "https://www.youtube.com/"))
        let plan = ValidatedPlan.phase1Allow(RawPlan(steps: [PlanStep(action: .openURL(url))]))

        await #expect(throws: ExecutorError.unsupportedStep) {
            try await router.dispatch(plan)
        }
    }
}
