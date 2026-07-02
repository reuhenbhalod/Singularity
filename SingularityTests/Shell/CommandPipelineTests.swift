//
//  CommandPipelineTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// No-op web driver so the pipeline runs end to end without touching
/// WebKit (the compositor still gets a real pane; navigation/JS are
/// stubbed out).
@MainActor
private final class StubWebPaneDriver: WebPaneDriving {
    func navigate(_ controller: WebPaneController, to url: URL) async throws {}
    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        // Pretend the hook found a video, and that it then plays, so
        // dispatch reaches the "playing newest …" result.
        if javaScript.contains(".play()") { return "playing" }
        return "https://www.youtube.com/watch?v=TEST"
    }
}

/// A planner that always returns a fixed plan (or nil).
private struct FixedPlanner: PlannerProtocol {
    let fixed: RawPlan?
    func plan(_ input: String) async throws -> RawPlan? { fixed }
}

/// The wired-up pipeline plus the stores to assert against.
@MainActor
private struct Harness {
    let pipeline: CommandPipeline
    let compositor: CompositorStore
    let log: SessionLogStore

    init() {
        compositor = CompositorStore()
        log = SessionLogStore()
        let router = ExecutorRouter(lanes: [WebLane(compositor: compositor, driver: StubWebPaneDriver())])
        pipeline = CommandPipeline(planner: StringMatcherPlanner(), router: router, log: log)
    }
}

@MainActor
struct CommandPipelineTests {
    /// T-P1-10 acceptance: the hero command ends with a YouTube pane in
    /// the compositor and the log showing the command + the result.
    @Test func heroCommandOpensPaneAndLogsResult() async {
        let harness = Harness()
        let (compositor, log) = (harness.compositor, harness.log)

        await harness.pipeline.run("play mrbeast newest video")

        #expect(compositor.panes.count == 1)
        guard case .web = compositor.panes[0].kind else {
            Issue.record("expected a web pane, got \(compositor.panes[0].kind)")
            return
        }

        let texts = log.entries.map(\.text)
        #expect(texts.contains("play mrbeast newest video"))
        #expect(texts.contains("playing newest MrBeast video"))
    }

    /// T-P7-16: invoking a routine expands to its steps, each re-entering
    /// the pipeline. A one-step "play mrbeast" routine ends with a web
    /// pane and the hero result, plus the routine banner.
    @Test func routineInvocationExpandsAndRuns() async {
        let compositor = CompositorStore()
        let log = SessionLogStore()
        let router = ExecutorRouter(lanes: [WebLane(compositor: compositor, driver: StubWebPaneDriver())])
        let store = RoutineStore(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("rt-\(UUID().uuidString).json"))
        try? await store.upsert(
            Routine(
                name: "demo", steps: ["play mrbeast newest video"],
                createdAt: Date(), updatedAt: Date()))
        let pipeline = CommandPipeline(
            planner: StringMatcherPlanner(), router: router, log: log, routineStore: store)

        await pipeline.run("demo")

        #expect(compositor.panes.count == 1)
        let texts = log.entries.map(\.text)
        #expect(texts.contains("Routine 'demo' → 1 step."))
        #expect(texts.contains("playing newest MrBeast video"))
    }

    /// The command is echoed as a `.command` entry and the result as a
    /// `.result` entry.
    @Test func logsCommandThenResultKinds() async {
        let harness = Harness()

        await harness.pipeline.run("play mrbeast newest video")

        #expect(harness.log.entries.first?.kind == .command)
        #expect(harness.log.entries.contains { $0.kind == .result })
    }

    /// A command containing a secret is blocked at the input boundary:
    /// no pane, no planner "don't know" line, and the raw secret is
    /// never echoed into the log.
    @Test func secretInputIsBlockedBeforePlanning() async {
        let harness = Harness()

        await harness.pipeline.run("here is AKIAIOSFODNN7EXAMPLE for you")

        let texts = harness.log.entries.map(\.text)
        #expect(texts.contains { $0.contains("AWS key") })
        #expect(harness.compositor.panes.isEmpty)
        #expect(!texts.contains("I don't know how to do that yet."))
        #expect(!texts.contains { $0.contains("AKIAIOSFODNN7EXAMPLE") })
    }

    /// T-P5-21 hardening: a plan whose URL is off the allowlist is
    /// rejected by the PlanValidator — surfaced with a reason, and it
    /// never reaches the executor (no pane).
    @Test func offAllowlistPlanIsRejectedWithReason() async throws {
        let url = try #require(URL(string: "https://evil.example.com/"))
        let log = SessionLogStore()
        let compositor = CompositorStore()
        let router = ExecutorRouter(
            lanes: [WebLane(compositor: compositor, driver: StubWebPaneDriver())])
        let pipeline = CommandPipeline(
            planner: FixedPlanner(fixed: RawPlan(steps: [PlanStep(action: .webNavigate(url))])),
            router: router,
            log: log)

        await pipeline.run("go to evil")

        #expect(log.entries.map(\.text).contains { $0.contains("allowed-sites list") })
        #expect(compositor.panes.isEmpty)
    }

    /// An unrecognized command opens no pane and logs a "don't know
    /// yet" system line.
    @Test func unrecognizedCommandLogsAndOpensNoPane() async {
        let harness = Harness()
        let (compositor, log) = (harness.compositor, harness.log)

        await harness.pipeline.run("make me a sandwich")

        #expect(compositor.panes.isEmpty)
        let texts = log.entries.map(\.text)
        #expect(texts.contains("make me a sandwich"))
        #expect(texts.contains("I don't know how to do that yet."))
    }
}
