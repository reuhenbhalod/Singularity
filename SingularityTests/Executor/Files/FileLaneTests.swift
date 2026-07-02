//
//  FileLaneTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct FileLaneTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// T-P6-06: move / copy / list behave.
    @Test func moveCopyList() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = dir.appendingPathComponent("a.txt")
        try "hi".write(to: a, atomically: true, encoding: .utf8)

        try FileOperations.copy(a, to: dir.appendingPathComponent("b.txt"))
        #expect(try FileOperations.list(dir).contains("b.txt"))

        try FileOperations.move(a, to: dir.appendingPathComponent("c.txt"))
        #expect(!FileManager.default.fileExists(atPath: a.path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("c.txt").path))
    }

    /// T-P6-06: delete goes to the Trash (source removed), not unlink.
    @Test func trashRemovesFromSource() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("trash-me.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        let trashed = try FileOperations.trash(file)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        try? FileManager.default.removeItem(at: trashed)  // tidy the Trash
    }

    /// T-P6-07: staging keeps only the newest `retain` snapshots.
    @Test func stagingRetainsNewest() throws {
        let base = try tempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("staging")
        let src = base.appendingPathComponent("s.txt")
        try "x".write(to: src, atomically: true, encoding: .utf8)

        let staging = StagingStore(root: root, retain: 2)
        for index in 0..<4 {
            try staging.stage(src, stamp: String(format: "%03d", index))
        }
        #expect(staging.snapshotCount() == 2)
    }

    /// T-P6-12: the sandbox runs a whitelisted command and returns output.
    @Test func sandboxRunsEcho() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await SandboxExecRunner().run("echo hello", scope: dir)
        #expect(result.stdout.contains("hello"))
    }
}
