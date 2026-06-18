//
//  CompositorViewTests.swift
//  SingularityTests
//

import SwiftUI
import Testing

@testable import Singularity

@MainActor
struct CompositorViewTests {
    /// View instantiates with 0, 1, 2, 3, and 4 panes and wraps in
    /// NSHostingView without crashing.
    @Test func viewInstantiatesAtEveryPaneCount() {
        for count in 0...CompositorStore.maxPanes {
            let store = CompositorStore()
            for index in 0..<count {
                store.add(Pane(title: "pane-\(index)"))
            }
            let hosting = NSHostingView(rootView: CompositorView(store: store))
            #expect(hosting.rootView is CompositorView)
        }
    }
}
