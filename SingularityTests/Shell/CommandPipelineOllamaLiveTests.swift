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
    private func skipIfOllamaDown() async throws {
        do {
            _ = try await OllamaClient().tags()
        } catch {
            throw XCTSkip("Ollama not reachable at localhost:11434 — live pipeline test skipped.")
        }
    }

    /// T-P2-09 regression: the hero command still works end to end with
    /// the live planner — opens a web pane and logs a result.
    func testHeroCommandWorksEndToEndWithOllama() async throws {
        try await skipIfOllamaDown()
        let compositor = CompositorStore()
        let log = SessionLogStore()
        let pipeline = CommandPipeline(
            planner: OllamaPlanner(client: OllamaClient()),
            router: ExecutorRouter(compositor: compositor, driver: StubWebPaneDriver()),
            log: log
        )

        await pipeline.run("play mrbeast newest video")

        let hasWebPane = compositor.panes.contains { if case .web = $0.kind { return true } else { return false } }
        XCTAssertTrue(hasWebPane, "expected a web pane; log: \(log.entries.map(\.text))")
        XCTAssertTrue(
            log.entries.contains { $0.kind == .result },
            "expected a result line; log: \(log.entries.map(\.text))"
        )
    }

    /// T-P2-09: a non-hero command still yields a valid plan from the
    /// planner (the executor may not handle it yet — that's fine).
    func testGenericCommandProducesAValidPlan() async throws {
        try await skipIfOllamaDown()
        let planner = OllamaPlanner(client: OllamaClient())

        let result = try await planner.plan("open google")
        let plan = try XCTUnwrap(result, "planner returned nil for 'open google'")
        XCTAssertFalse(plan.steps.isEmpty)
    }
}
