//
//  RoutineStoreTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct RoutineStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("routines-\(UUID().uuidString).json")
    }

    private func routine(_ name: String, _ steps: [String]) -> Routine {
        Routine(name: name, steps: steps, createdAt: Date(), updatedAt: Date())
    }

    /// T-P5-17: a missing file loads as empty.
    @Test func missingFileIsEmpty() async {
        let store = RoutineStore(url: tempURL())
        #expect(await store.all().isEmpty)
    }

    /// Upsert persists atomically and survives reopening the file.
    @Test func upsertPersistsAcrossInstances() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try await RoutineStore(url: url).upsert(routine("Dev", ["open vscode", "cd ~/code"]))

        let reopened = await RoutineStore(url: url).all()
        #expect(reopened.count == 1)
        #expect(reopened.first?.name == "Dev")
        #expect(reopened.first?.steps == ["open vscode", "cd ~/code"])
    }

    /// Delete is case-insensitive and removes the entry.
    @Test func deleteRemoves() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = RoutineStore(url: url)

        try await store.upsert(routine("dev", ["x"]))
        try await store.delete(name: "DEV")

        #expect(await store.all().isEmpty)
    }

    /// Concurrent upserts serialize through the actor without loss.
    @Test func concurrentUpsertsSerialize() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = RoutineStore(url: url)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<10 {
                group.addTask { try? await store.upsert(self.routine("r\(index)", ["s"])) }
            }
        }

        #expect(await store.all().count == 10)
    }
}
