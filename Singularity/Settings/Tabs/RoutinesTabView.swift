//
//  RoutinesTabView.swift
//  Singularity
//

import SwiftUI

/// Loads and manages the user's saved routines for the Settings window
/// (US-RT-3/5). Creation stays in the shell (`routine NAME = ...`); this
/// tab lists what exists and lets you delete.
@MainActor
@Observable
final class RoutinesViewModel {
    private let store: RoutineStore
    private(set) var routines: [Routine] = []

    init(store: RoutineStore = RoutineStore()) {
        self.store = store
    }

    func load() async {
        routines = await store.all()
    }

    func delete(_ routine: Routine) async {
        try? await store.delete(name: routine.name)
        await load()
    }
}

struct RoutinesTabView: View {
    @State private var model: RoutinesViewModel

    init(store: RoutineStore = RoutineStore()) {
        _model = State(initialValue: RoutinesViewModel(store: store))
    }

    var body: some View {
        Form {
            Section {
                if model.routines.isEmpty {
                    Text("No routines yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.routines, id: \.name) { routine in
                        RoutineRow(routine: routine) {
                            Task { await model.delete(routine) }
                        }
                    }
                }
            } header: {
                Text("Saved routines")
            } footer: {
                Text(
                    "Create one from the shell: `routine deploy = open terminal; run tests`. "
                        + "Invoke it by name, or `run deploy`.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await model.load() }
    }
}

/// A single routine: name, step count, the steps themselves, and delete.
private struct RoutineRow: View {
    let routine: Routine
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(routine.name).font(.body.monospaced()).bold()
                    Text("\(routine.steps.count) step\(routine.steps.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(routine.steps.joined(separator: "  →  "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
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
