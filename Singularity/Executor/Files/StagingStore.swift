//
//  StagingStore.swift
//  Singularity
//

import Foundation

/// Copies a file into a timestamped staging directory before it's mutated
/// in place, keeping the newest `retain` copies (brief §7 / T-P6-07). The
/// safety net for move/overwrite operations.
struct StagingStore {
    private let root: URL
    private let retain: Int

    init(root: URL? = nil, retain: Int = 10) {
        self.root =
            root
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Singularity/staging", isDirectory: true)
        self.retain = retain
    }

    /// Stages a copy of `url`, then prunes to the newest `retain`.
    /// `stamp` is injectable so tests get deterministic, ordered names.
    @discardableResult
    func stage(_ url: URL, stamp: String = StagingStore.timestamp()) throws -> URL {
        let dir = root.appendingPathComponent(stamp, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let copied = dir.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: copied)
        try prune()
        return copied
    }

    /// Number of staged snapshots currently retained.
    func snapshotCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: root.path).count) ?? 0
    }

    private func prune() throws {
        let dirs = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        guard dirs.count > retain else { return }
        for old in dirs.prefix(dirs.count - retain) {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(old))
        }
    }

    static func timestamp() -> String {
        // Sortable + unique enough for rapid successive stages.
        String(format: "%020.6f-%@", Date().timeIntervalSince1970, UUID().uuidString)
    }
}
