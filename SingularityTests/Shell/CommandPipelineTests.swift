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
        // Pretend the hook found a video so dispatch reaches the
        // "playing newest …" result.
        "https://www.youtube.com/watch?v=TEST"
    }
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
        let router = ExecutorRouter(compositor: compositor, driver: StubWebPaneDriver())
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

    /// The command is echoed as a `.command` entry and the result as a
    /// `.result` entry.
    @Test func logsCommandThenResultKinds() async {
        let harness = Harness()

        await harness.pipeline.run("play mrbeast newest video")

        #expect(harness.log.entries.first?.kind == .command)
        #expect(harness.log.entries.contains { $0.kind == .result })
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
