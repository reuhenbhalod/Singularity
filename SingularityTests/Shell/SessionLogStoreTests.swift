//
//  SessionLogStoreTests.swift
//  SingularityTests
//

import Testing

@testable import Singularity

@MainActor
struct SessionLogStoreTests {
    /// T-P0-09 acceptance: append adds entries to the in-memory list.
    @Test func appendAddsEntryToEntries() {
        let store = SessionLogStore()

        store.append(kind: .command, "play mrbeast newest video")

        #expect(store.entries.count == 1)
        #expect(store.entries[0].kind == .command)
        #expect(store.entries[0].text == "play mrbeast newest video")
    }

    /// T-P0-09 acceptance: clear() empties the list.
    @Test func clearRemovesAllEntries() {
        let store = SessionLogStore()
        store.append(kind: .command, "a")
        store.append(kind: .system, "b")
        store.append(kind: .result, "c")

        store.clear()

        #expect(store.entries.isEmpty)
    }

    /// T-P0-09 acceptance: entries preserve append order (the view
    /// renders them in this order).
    @Test func entriesPreserveAppendOrder() {
        let store = SessionLogStore()

        store.append(kind: .command, "first")
        store.append(kind: .system, "second")
        store.append(kind: .command, "third")

        #expect(store.entries.map(\.text) == ["first", "second", "third"])
        #expect(store.entries.map(\.kind) == [.command, .system, .command])
    }

    @Test func newStoreStartsEmpty() {
        let store = SessionLogStore()
        #expect(store.entries.isEmpty)
    }

    @Test func entriesHaveStableUniqueIDs() {
        let store = SessionLogStore()
        store.append(kind: .command, "a")
        store.append(kind: .command, "a")  // same text, should still get unique id

        #expect(store.entries[0].id != store.entries[1].id)
    }
}
