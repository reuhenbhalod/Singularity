//
//  CompositorStoreTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct CompositorStoreTests {
    /// T-P0-10 acceptance: adding panes increases the count.
    @Test func addAppendsPaneToList() {
        let store = CompositorStore()

        store.add(Pane(title: "youtube.com"))

        #expect(store.panes.count == 1)
        #expect(store.panes[0].title == "youtube.com")
    }

    /// T-P0-10 acceptance: closing reduces the count.
    @Test func removeByIDDropsPane() {
        let store = CompositorStore()
        let paneA = Pane(title: "a")
        let paneB = Pane(title: "b")
        store.add(paneA)
        store.add(paneB)

        store.remove(id: paneA.id)

        #expect(store.panes.count == 1)
        #expect(store.panes[0].title == "b")
    }

    /// add beyond the 4-pane cap is silently dropped (spec only
    /// defines 1/2/3/4-pane layouts).
    @Test func addBeyondCapIsNoop() {
        let store = CompositorStore()
        for index in 1...5 {
            store.add(Pane(title: "p\(index)"))
        }

        #expect(store.panes.count == CompositorStore.maxPanes)
        #expect(store.panes.map(\.title) == ["p1", "p2", "p3", "p4"])
    }

    @Test func clearDropsAllPanes() {
        let store = CompositorStore()
        store.add(Pane(title: "a"))
        store.add(Pane(title: "b"))

        store.clear()

        #expect(store.panes.isEmpty)
    }

    @Test func newStoreStartsEmpty() {
        let store = CompositorStore()
        #expect(store.panes.isEmpty)
    }

    @Test func removeOfUnknownIDIsNoop() {
        let store = CompositorStore()
        store.add(Pane(title: "a"))

        store.remove(id: UUID())

        #expect(store.panes.count == 1)
    }
}
