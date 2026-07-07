//
//  RoutinesTabView.swift
//  Singularity
//

import AppKit
import SwiftUI

/// Loads and manages the user's saved routines for the Settings window
/// (US-SET-4, US-RT-3/4/5). Creation stays inline in the shell (§6 #12);
/// this tab lists, edits (steps only), and deletes.
@MainActor
@Observable
final class RoutinesViewModel {
    private let store: RoutineStore
    let fileURL: URL
    private(set) var routines: [Routine] = []

    init(store: RoutineStore = RoutineStore(), fileURL: URL = RoutineStore.defaultURL()) {
        self.store = store
        self.fileURL = fileURL
    }

    func load() async {
        routines = await store.all()
    }

    func delete(_ routine: Routine) async {
        try? await store.delete(name: routine.name)
        await load()
    }

    /// Saves edited steps for an existing routine (name is read-only). The
    /// step text is validated by the same parser as the inline
    /// `routine NAME = …` form (US-RT-4). Returns an error message on
    /// failure (leaving the stored routine unchanged), or nil on success.
    func save(name: String, stepsText: String, now: Date = Date()) async -> String? {
        switch RoutineParser.parse("\(name) = \(stepsText)", honorOverwriteToken: false) {
        case .failure(let message):
            return message
        case .definition(_, let steps, _):
            let created = routines.first { $0.name == name }?.createdAt ?? now
            do {
                try await store.upsert(
                    Routine(name: name, steps: steps, createdAt: created, updatedAt: now))
                await load()
                return nil
            } catch {
                return "Couldn't save that routine."
            }
        }
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}

struct RoutinesTabView: View {
    @State private var model: RoutinesViewModel
    @State private var editing: Routine?
    @State private var pendingDelete: Routine?

    init(store: RoutineStore = RoutineStore(), fileURL: URL = RoutineStore.defaultURL()) {
        _model = State(initialValue: RoutinesViewModel(store: store, fileURL: fileURL))
    }

    var body: some View {
        Form {
            Section {
                if model.routines.isEmpty {
                    Text("No routines defined. Create one with `routine NAME = step1; step2`.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.routines, id: \.name) { routine in
                        RoutineRow(
                            routine: routine,
                            onEdit: { editing = routine },
                            onDelete: { pendingDelete = routine })
                    }
                }
            } header: {
                Text("Saved routines")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Create one from the shell: `routine deploy = open terminal; run tests`. Invoke it by name, or `run deploy`.")
                    Button("Reveal routines.json in Finder") { model.revealInFinder() }
                        .buttonStyle(.link)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await model.load() }
        .sheet(item: $editing) { routine in
            RoutineDetailView(routine: routine) { stepsText in
                await model.save(name: routine.name, stepsText: stepsText)
            } onClose: {
                editing = nil
            }
        }
        .confirmationDialog(
            pendingDelete.map { "Delete routine '\($0.name)'? This cannot be undone." } ?? "",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let routine = pendingDelete {
                    Task { await model.delete(routine) }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}

/// A single routine row: name, step count, a preview, and edit/delete.
private struct RoutineRow: View {
    let routine: Routine
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(routine.name).font(.body.monospaced()).bold()
                        Text("\(routine.steps.count) step\(routine.steps.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(routine.steps.joined(separator: "  →  "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this routine")
        }
        .padding(.vertical, 2)
    }
}

/// Edit sheet for a routine's steps. Name is read-only (rename = delete +
/// recreate, per US-RT-4). Save runs the same parser as inline creation; a
/// validation failure keeps the sheet open with an inline error.
private struct RoutineDetailView: View {
    let routine: Routine
    let onSave: (String) async -> String?
    let onClose: () -> Void

    @State private var stepsText: String
    @State private var error: String?
    @State private var saving = false

    init(routine: Routine, onSave: @escaping (String) async -> String?, onClose: @escaping () -> Void) {
        self.routine = routine
        self.onSave = onSave
        self.onClose = onClose
        _stepsText = State(initialValue: routine.steps.joined(separator: "; "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(routine.name).font(.title2.monospaced().bold())
            Text("Steps, separated by `;`").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $stepsText)
                .font(.body.monospaced())
                .frame(minHeight: 120)
                .border(.quaternary)
            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                Button("Save") {
                    saving = true
                    Task {
                        error = await onSave(stepsText)
                        saving = false
                        if error == nil { onClose() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saving)
            }
        }
        .padding(20)
        .frame(width: 420, height: 300)
    }
}
