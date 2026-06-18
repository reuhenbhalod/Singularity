//
//  CompositorStore.swift
//  Singularity
//

import Foundation
import Observation

/// In-memory store of currently open panes. Capped at `maxPanes`
/// because the spec's 1/2/3/4 layouts don't extend further; an
/// `add` beyond the cap is a no-op so callers don't have to check.
@MainActor
@Observable
final class CompositorStore {
    static let maxPanes = 4

    private(set) var panes: [Pane] = []

    func add(_ pane: Pane) {
        guard panes.count < Self.maxPanes else { return }
        panes.append(pane)
    }

    func remove(id: UUID) {
        panes.removeAll { $0.id == id }
    }

    func clear() {
        panes.removeAll()
    }
}
