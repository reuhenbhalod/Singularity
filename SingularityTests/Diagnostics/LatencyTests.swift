//
//  LatencyTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// No-op web driver so a hero command runs end-to-end without WebKit.
@MainActor
private final class StubWebPaneDriver: WebPaneDriving {
    func navigate(_ controller: WebPaneController, to url: URL) async throws {}
    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        javaScript.contains(".play()") ? "playing" : "https://www.youtube.com/watch?v=TEST"
    }
}

/// T-P7-23 latency budgets. These measure the parts under the app's own
/// control — AppKit summon and the pipeline's non-Ollama overhead. Hero
/// end-to-end latency is dominated by the local model and is verified
/// manually on representative hardware (documented in plan §8).
@MainActor
struct LatencyTests {
    /// Hotkey-to-focus budget is 150ms (US-S-1). Measured warm (a first
    /// show pays one-time SwiftUI hosting-init cost, so we warm up once).
    @Test func summonToFocusWithinBudget() {
        let controller = ShellWindowController()
        // Warm up: pay one-time costs (hosting view, panel class realize).
        controller.show()
        controller.hide()

        let ms = Latency.elapsedMs { controller.show() }
        controller.hide()

        print("[latency] hotkey_to_focus (warm): \(ms) ms")
        #expect(ms < 150)
    }

    /// The pipeline's overhead excluding the planner — input validation,
    /// routine resolution, plan validation, gates, dispatch — must be a
    /// small slice of the 5s hero budget, leaving essentially all of it to
    /// Ollama. Uses an instant matcher planner.
    @Test func commandOverheadIsSmall() async {
        let compositor = CompositorStore()
        let log = SessionLogStore()
        let router = ExecutorRouter(lanes: [WebLane(compositor: compositor, driver: StubWebPaneDriver())])
        let store = RoutineStore(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("lat-\(UUID().uuidString).json"))
        let pipeline = CommandPipeline(
            planner: StringMatcherPlanner(), router: router, log: log, routineStore: store)

        // Warm up the path once.
        await pipeline.run("play mrbeast newest video")

        let start = DispatchTime.now().uptimeNanoseconds
        await pipeline.run("play mrbeast newest video")
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

        print("[latency] command_overhead (no Ollama): \(ms) ms")
        #expect(ms < 500)
    }
}
