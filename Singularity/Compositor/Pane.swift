//
//  Pane.swift
//  Singularity
//

import Foundation

/// One pane in the compositor. The `kind` discriminator carries the
/// pane's content: a placeholder tile, or a live web pane wrapping a
/// `WebPaneController`'s `WKWebView` (T-P1-08). Later phases add cases
/// for AX / file viewers.
struct Pane: Identifiable {
    let id: UUID
    var title: String
    var kind: Kind

    enum Kind {
        case placeholder
        case web(WebPaneController)
    }

    init(title: String, kind: Kind = .placeholder, id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}

extension Pane: Equatable {
    /// Identity-based: panes are unique by `id`. (`Kind.web` wraps a
    /// reference type that is not `Equatable`, and identity is the only
    /// equality the compositor needs.)
    static func == (lhs: Pane, rhs: Pane) -> Bool {
        lhs.id == rhs.id
    }
}
