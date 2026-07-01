//
//  RoutineStore.swift
//  Singularity
//

import Foundation

/// Persists user-authored routines to
/// `~/Library/Application Support/Singularity/routines.json`, atomically
/// (write-temp + rename, via `Data.write(options: .atomic)`), serialized
/// through an actor so concurrent edits can't corrupt the file (spec §6
/// #13). Storage only — the inline/Settings UI is Phase 7.
actor RoutineStore {
    private let url: URL
    private var cache: [String: Routine]?

    init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL()
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return
            base
            .appendingPathComponent("Singularity", isDirectory: true)
            .appendingPathComponent("routines.json")
    }

    /// All routines, sorted by name. Missing file → empty.
    func all() -> [Routine] {
        let routines = (try? load()) ?? [:]
        return routines.values.sorted { $0.name < $1.name }
    }

    /// Inserts or replaces a routine (keyed by lowercased name) and
    /// persists atomically.
    func upsert(_ routine: Routine) throws {
        var routines = (try? load()) ?? [:]
        routines[routine.name.lowercased()] = routine
        try save(routines)
    }

    /// Removes a routine by name (no-op if absent) and persists.
    func delete(name: String) throws {
        var routines = (try? load()) ?? [:]
        routines[name.lowercased()] = nil
        try save(routines)
    }

    // MARK: - Persistence

    private func load() throws -> [String: Routine] {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: url.path) else {
            cache = [:]
            return [:]
        }
        let data = try Data(contentsOf: url)
        let list = try JSONDecoder().decode([Routine].self, from: data)
        let map = Dictionary(list.map { ($0.name.lowercased(), $0) }) { _, latest in latest }
        cache = map
        return map
    }

    private func save(_ routines: [String: Routine]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(routines.values.sorted { $0.name < $1.name })
        try data.write(to: url, options: .atomic)
        cache = routines
    }
}
