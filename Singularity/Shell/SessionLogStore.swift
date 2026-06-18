//
//  SessionLogStore.swift
//  Singularity
//

import Observation

/// In-memory backing store for the session log strip. Created fresh
/// on each `ShellWindowController.show` so each summon starts with an
/// empty log (principle 4 of the spec: no cross-session command
/// history). `clear()` is exposed so `hide()` can explicitly drop
/// entries before the store is replaced on next show.
@MainActor
@Observable
final class SessionLogStore {
    private(set) var entries: [SessionLogEntry] = []

    func append(kind: SessionLogEntry.Kind, _ text: String) {
        entries.append(SessionLogEntry(kind: kind, text: text))
    }

    func clear() {
        entries.removeAll()
    }
}
