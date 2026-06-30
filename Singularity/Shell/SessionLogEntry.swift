//
//  SessionLogEntry.swift
//  Singularity
//

import Foundation

/// One entry in the ephemeral session log strip.
///
/// Brief §11.7 expands this in Phase 5 (privacy markers, hashes-not-
/// content, etc.); v1 keeps it minimal so the strip can render.
struct SessionLogEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case command  // what the user typed
        case system  // a system line (truncation, dismiss, etc.)
        case result  // result of executing a command (later phases)
        case banner  // a prominent, non-blocking alert (e.g. permission revoked)
    }

    let id: UUID
    let kind: Kind
    let text: String

    init(kind: Kind, text: String, id: UUID = UUID()) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}
