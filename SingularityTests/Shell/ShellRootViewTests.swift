//
//  ShellRootViewTests.swift
//  SingularityTests
//

import SwiftUI
import Testing

@testable import Singularity

@MainActor
struct ShellRootViewTests {
    /// T-P0-07 acceptance: the scaffolding view instantiates and can
    /// be wrapped in an NSHostingView (the AppKit bridge the
    /// controller uses to mount it on the panel). Deeper layout
    /// assertions are deferred to manual verification because they
    /// would require a snapshot library, which would be a third-party
    /// SPM dep (off-limits per CLAUDE.md without explicit
    /// justification).
    @Test func viewInstantiatesAndHostsCleanly() {
        let view = ShellRootView(
            commandInputViewModel: CommandInputViewModel(),
            sessionLog: SessionLogStore(),
            compositor: CompositorStore()
        )
        let hosting = NSHostingView(rootView: view)
        #expect(hosting.rootView is ShellRootView)
    }
}
