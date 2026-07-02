//
//  RoutineCommandHandler.swift
//  Singularity
//

import Foundation

/// Handles the inline routine-management commands — create, list, show,
/// delete (US-RT-1/3/4/5) — writing through the `RoutineStore`. Delete
/// requires a literal `confirm` on the next input; overwrite requires a
/// trailing `overwrite` token.
@MainActor
final class RoutineCommandHandler {
    private let store: RoutineStore
    private let log: (SessionLogEntry.Kind, String) -> Void
    private let now: () -> Date
    private var pendingDelete: String?

    init(
        store: RoutineStore,
        now: @escaping () -> Date = Date.init,
        log: @escaping (SessionLogEntry.Kind, String) -> Void
    ) {
        self.store = store
        self.now = now
        self.log = log
    }

    /// Handles a routine-management command; returns whether `input` was
    /// one (so the pipeline can stop).
    func handle(_ input: String) async -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        if let name = pendingDelete {
            pendingDelete = nil
            if lower == "confirm" {
                try? await store.delete(name: name)
                log(.result, "Routine '\(name)' deleted.")
            } else {
                log(.system, "Cancelled — '\(name)' kept.")
            }
            return true
        }

        if lower == "routines" {
            await listAll()
            return true
        }
        if lower.hasPrefix("routine delete ") {
            await startDelete(String(trimmed.dropFirst("routine delete ".count)))
            return true
        }
        if lower.hasPrefix("routine ") {
            let rest = String(trimmed.dropFirst("routine ".count))
            if rest.contains("=") {
                await create(rest)
            } else {
                await showOne(rest.trimmingCharacters(in: .whitespaces))
            }
            return true
        }
        return false
    }

    private func create(_ definition: String) async {
        switch RoutineParser.parse(definition) {
        case .failure(let message):
            log(.system, message)
        case .definition(let name, let steps, let overwrite):
            let existing = await store.all().first { $0.name == name }
            if let existing, !overwrite {
                log(
                    .system,
                    "Routine '\(name)' already exists with \(existing.steps.count) steps. Add 'overwrite' to replace it, or 'routine delete \(name)' first.")
                return
            }
            let timestamp = now()
            let routine = Routine(
                name: name, steps: steps,
                createdAt: existing?.createdAt ?? timestamp, updatedAt: timestamp)
            do {
                try await store.upsert(routine)
                log(.result, "Routine '\(name)' saved (\(steps.count) steps).")
            } catch {
                log(.system, "Couldn't save that routine.")
            }
        }
    }

    private func startDelete(_ nameText: String) async {
        let name = nameText.trimmingCharacters(in: .whitespaces).lowercased()
        guard let existing = await store.all().first(where: { $0.name == name }) else {
            log(.system, "No routine named '\(name)'.")
            return
        }
        pendingDelete = name
        log(.system, "Delete routine '\(name)' (\(existing.steps.count) steps)? Type 'confirm' to delete.")
    }

    private func showOne(_ nameText: String) async {
        let name = nameText.lowercased()
        guard let routine = await store.all().first(where: { $0.name == name }) else {
            log(.system, "No routine named '\(name)'. Create one with: routine \(nameText) = step1; step2")
            return
        }
        log(.result, "\(routine.name): \(routine.steps.joined(separator: "; "))")
    }

    private func listAll() async {
        let all = await store.all()
        guard !all.isEmpty else {
            log(.system, "No routines defined. Create one with: routine NAME = step1; step2")
            return
        }
        for routine in all {
            log(.result, "\(routine.name) (\(routine.steps.count) steps): \(routine.steps.joined(separator: "; "))")
        }
    }
}
