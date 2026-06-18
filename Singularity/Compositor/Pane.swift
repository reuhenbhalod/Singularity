//
//  Pane.swift
//  Singularity
//

import Foundation

/// One pane in the compositor. Phase 0 only renders placeholder
/// panes via the title; future phases (T-P3-* for WKWebView panes,
/// T-P4-* for AX panes) will add a kind/content discriminator.
struct Pane: Identifiable, Equatable {
    let id: UUID
    var title: String

    init(title: String, id: UUID = UUID()) {
        self.id = id
        self.title = title
    }
}
