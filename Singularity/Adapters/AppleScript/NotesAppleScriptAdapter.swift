//
//  NotesAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Reads the Notes app via AppleScript (research brief §6). Read-only in
/// v1 — creating a note needs a body argument, which the parameterless
/// hook schema can't carry (deferred to a parameterized action later).
struct NotesAppleScriptAdapter: AppleScriptAdapter {
    let name = "notes"

    let scripts = [
        "count": "tell application \"Notes\" to return (count of notes) & \" notes\"",
    ]
}
