//
//  FileOperations.swift
//  Singularity
//

import Foundation

/// Native file operations via `FileManager` (brief §7 / T-P6-06).
/// Deletions ALWAYS go to the Trash — never `removeItem`/`unlink` — so a
/// user-initiated delete is always recoverable (the APFS-snapshot
/// replacement from the spec).
enum FileOperations {
    /// Moves `source` to the Trash, returning where it landed.
    static func trash(_ source: URL) throws -> URL {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: source, resultingItemURL: &resulting)
        return (resulting as URL?) ?? source
    }

    static func move(_ source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    static func copy(_ source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    /// Sorted directory listing (names only).
    static func list(_ directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }
}
