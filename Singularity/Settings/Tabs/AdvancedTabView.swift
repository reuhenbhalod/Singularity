//
//  AdvancedTabView.swift
//  Singularity
//

import SwiftUI

/// Power-user tab: a read-only view of the recent safety log (T-P7-20) and
/// a factory reset (T-P7-22). Both reinforce the local-only, nothing-hidden
/// stance — the same events you can dump with `/safety log` in the shell.
struct AdvancedTabView: View {
    @Bindable var settings: SettingsStore
    @Bindable var account: AccountModel

    @State private var logs: [SafetyLogLine] = []
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section {
                if logs.isEmpty {
                    Text("No safety events in the last hour.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(logs) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.message).font(.callout)
                            Text(line.date, format: .dateTime.hour().minute().second())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 1)
                    }
                }
            } header: {
                HStack {
                    Text("Safety log — last hour")
                    Spacer()
                    Button("Refresh") { reload() }.buttonStyle(.link)
                }
            } footer: {
                Text("The same events as `/safety log` in the shell. Local only — nothing leaves this machine.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button("Factory Reset…", role: .destructive) { confirmingReset = true }
            } header: {
                Text("Reset")
            } footer: {
                Text("Clears all settings, saved routines, and your signed-in account. Everything is local, so this fully resets the app.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { reload() }
        .confirmationDialog(
            "Reset Singularity to defaults?", isPresented: $confirmingReset, titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                FactoryReset.run(settings: settings)
                account.signOut()
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears settings, routines, and your account. It can't be undone.")
        }
    }

    private func reload() {
        logs = SafetyLogReader.recent()
    }
}
