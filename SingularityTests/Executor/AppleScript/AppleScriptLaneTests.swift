//
//  AppleScriptLaneTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct AppleScriptLaneTests {
    /// T-P6-02: claims known adapter+hook, declines unknown hooks,
    /// unknown adapters, and non-AppleScript actions.
    @Test func canHandleKnownAdapterHook() {
        let lane = AppleScriptLane()
        #expect(lane.canHandle(PlanStep(action: .appleScript(adapter: "music", hook: "playpause"))))
        #expect(!lane.canHandle(PlanStep(action: .appleScript(adapter: "music", hook: "teleport"))))
        #expect(!lane.canHandle(PlanStep(action: .appleScript(adapter: "excel", hook: "x"))))
        #expect(!lane.canHandle(PlanStep(action: .axAction(adapter: "music", hook: "playpause"))))
    }

    /// Honest feedback for an unknown app and an unsupported hook.
    @Test func diagnoseExplains() {
        let lane = AppleScriptLane()
        #expect(
            lane.diagnose(PlanStep(action: .appleScript(adapter: "excel", hook: "x")))?
                .contains("excel") == true)
        #expect(
            lane.diagnose(PlanStep(action: .appleScript(adapter: "music", hook: "teleport")))?
                .contains("playpause") == true)
    }
}

@MainActor
struct CompiledScriptCacheTests {
    /// T-P6-02: a script compiles once and is reused on the next request.
    @Test func compilesOnceAndReuses() {
        let cache = CompiledScriptCache()
        #expect(cache.script(for: "return 1 + 1") != nil)
        #expect(cache.count == 1)
        _ = cache.script(for: "return 1 + 1")
        #expect(cache.count == 1)
        _ = cache.script(for: "return 2 + 2")
        #expect(cache.count == 2)
    }
}

struct MusicAppleScriptAdapterTests {
    /// The Music adapter exposes playback hooks with real Music scripts.
    @Test func declaresPlaybackHooks() {
        let adapter = MusicAppleScriptAdapter()
        #expect(adapter.name == "music")
        #expect(adapter.scripts["playpause"]?.contains("Music") == true)
        #expect(adapter.scripts["next"] != nil)
        #expect(adapter.scripts["current"] != nil)
    }
}
