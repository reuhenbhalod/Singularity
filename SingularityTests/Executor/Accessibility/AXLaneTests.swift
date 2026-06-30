//
//  AXLaneTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Mock adapter targeting Finder (always running) so `AXApplication`
/// resolves; `perform` returns a canned summary without touching AX.
private struct MockAXAdapter: AXAdapter {
    let name = "mock"
    let bundleID = "com.apple.finder"
    let hooks: Set<String> = ["ping"]

    @MainActor
    func perform(_ hook: String, in app: AXApplication) throws -> String {
        "did \(hook) on mock"
    }
}

/// Adapter for an app that isn't running.
private struct GhostAXAdapter: AXAdapter {
    let name = "ghost"
    let bundleID = "com.singularity.not-running"
    let hooks: Set<String> = ["x"]

    @MainActor
    func perform(_ hook: String, in app: AXApplication) throws -> String { "" }
}

@MainActor
struct AXLaneTests {
    /// T-P4-04: an ax_action step is dispatched to its adapter.
    @Test func dispatchesAXActionToAdapter() async throws {
        let lane = AXLane(registry: AXAdapterRegistry(adapters: [MockAXAdapter()]))
        let step = PlanStep(action: .axAction(adapter: "mock", hook: "ping"))

        #expect(lane.canHandle(step))
        #expect(try await lane.execute(step) == .handled(summary: "did ping on mock"))
    }

    /// Declines an unknown adapter, an unknown hook, and non-AX actions.
    @Test func declinesUnsupportedSteps() throws {
        let lane = AXLane(registry: AXAdapterRegistry(adapters: [MockAXAdapter()]))
        let url = try #require(URL(string: "https://example.com"))

        #expect(!lane.canHandle(PlanStep(action: .axAction(adapter: "nope", hook: "ping"))))
        #expect(!lane.canHandle(PlanStep(action: .axAction(adapter: "mock", hook: "unknown"))))
        #expect(!lane.canHandle(PlanStep(action: .webNavigate(url))))
    }

    /// A target app that isn't running reports cleanly.
    @Test func reportsWhenAppNotRunning() async throws {
        let lane = AXLane(registry: AXAdapterRegistry(adapters: [GhostAXAdapter()]))
        let result = try await lane.execute(PlanStep(action: .axAction(adapter: "ghost", hook: "x")))
        #expect(result == .handled(summary: "ghost isn't running"))
    }

    /// Honest feedback: an unknown native app is explained, not silently
    /// dropped.
    @Test func diagnoseExplainsUnknownNativeApp() {
        let lane = AXLane(registry: AXAdapterRegistry(adapters: [MockAXAdapter()]))
        let reason = lane.diagnose(PlanStep(action: .axAction(adapter: "finder", hook: "open")))
        #expect(reason?.contains("finder") == true)
    }

    /// Honest feedback: an unsupported hook on a known app lists what the
    /// app *can* do.
    @Test func diagnoseListsSupportedHooks() {
        let lane = AXLane(registry: AXAdapterRegistry(adapters: [MockAXAdapter()]))
        let reason = lane.diagnose(PlanStep(action: .axAction(adapter: "mock", hook: "fly")))
        #expect(reason?.contains("ping") == true)  // the supported hook
    }

    /// The default registry resolves Spotify by name.
    @Test func registryResolvesSpotify() throws {
        let adapter = try #require(AXAdapterRegistry().adapter(named: "spotify"))
        #expect(adapter.bundleID == "com.spotify.client")
    }

    /// Unknown adapter name resolves to nil.
    @Test func registryUnknownNameIsNil() {
        #expect(AXAdapterRegistry().adapter(named: "nope") == nil)
    }
}
