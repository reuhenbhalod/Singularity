//
//  Routine.swift
//  Singularity
//

import Foundation

/// A user-authored named macro: a name and the ordered command strings it
/// expands to (brief §11 / spec §4 Routines). Stored locally as JSON; the
/// inline-command and Settings surfaces that create/invoke them land in
/// Phase 7. Names are matched lowercased.
struct Routine: Codable, Equatable {
    let name: String
    let steps: [String]
    let createdAt: Date
    let updatedAt: Date
}
