//
//  RoutinesViewModelTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct RoutinesViewModelTests {
    private func store() -> RoutineStore {
        RoutineStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("rvm-\(UUID().uuidString).json"))
    }

    /// US-RT-4: editing steps through the tab parses via the same parser
    /// and persists.
    @Test func saveValidStepsUpdatesRoutine() async throws {
        let store = store()
        try await store.upsert(
            Routine(name: "dev", steps: ["a"], createdAt: Date(), updatedAt: Date()))
        let model = RoutinesViewModel(store: store)
        await model.load()

        let error = await model.save(name: "dev", stepsText: "open code; run tests")
        #expect(error == nil)
        #expect(await store.all().first?.steps == ["open code", "run tests"])
    }

    /// US-RT-4: a validation failure leaves the stored routine unchanged.
    @Test func saveEmptyStepsFailsAndKeepsOriginal() async throws {
        let store = store()
        try await store.upsert(
            Routine(name: "dev", steps: ["a"], createdAt: Date(), updatedAt: Date()))
        let model = RoutinesViewModel(store: store)
        await model.load()

        let error = await model.save(name: "dev", stepsText: "   ")
        #expect(error != nil)
        #expect(await store.all().first?.steps == ["a"])
    }
}
