//
//  CommandPipelineOllamaLiveTests.swift
//  SingularityTests
//
//  Integration tests for the full Phase-2 pipeline driven by a real
//  Ollama model (T-P2-09). Run on the dev machine; XCTSkip when the
//  server is unreachable. Web side effects go through a stub driver so
//  no real WKWebView is needed.
//

import XCTest

@testable import Singularity

@MainActor
private final class StubWebPaneDriver: WebPaneDriving {
    func navigate(_ controller: WebPaneController, to url: URL) async throws {}
    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        javaScript.contains(".play()") ? "playing" : "https://www.youtube.com/watch?v=TEST"
    }
}

@MainActor
final class CommandPipelineOllamaLiveTests: XCTestCase {
    /// T-P2-09 regression: the hero command still works end to end with
    /// the live planner — opens a web pane and logs a result.
    func testHeroCommandWorksEndToEndWithOllama() async throws {
        try await LiveTestGate.requireLiveOllama()

        // Retry to absorb the 7B model's occasional single-shot variance
        // (the same planner the user invokes consistently gets there).
        var lastLog: [String] = []
        for _ in 0..<3 {
            let compositor = CompositorStore()
            let log = SessionLogStore()
            let pipeline = CommandPipeline(
                planner: OllamaPlanner(client: OllamaClient(timeout: 120)),
                router: ExecutorRouter(lanes: [WebLane(compositor: compositor, driver: StubWebPaneDriver())]),
                log: log
            )

            await pipeline.run("play mrbeast newest video")
            lastLog = log.entries.map(\.text)

            let hasWebPane = compositor.panes.contains {
                if case .web = $0.kind { return true } else { return false }
            }
            let hasResult = log.entries.contains { $0.kind == .result }
            if hasWebPane && hasResult { return }
        }
        XCTFail("hero command produced no web pane + result in 3 attempts; last log: \(lastLog)")
    }

    /// T-P2-09: a non-hero command still yields a valid plan from the
    /// planner (the executor may not handle it yet — that's fine).
    func testGenericCommandProducesAValidPlan() async throws {
        try await LiveTestGate.requireLiveOllama()
        let planner = OllamaPlanner(client: OllamaClient(timeout: 120))

        let result = try await planner.plan("open google")
        let plan = try XCTUnwrap(result, "planner returned nil for 'open google'")
        XCTAssertFalse(plan.steps.isEmpty)
    }
}
