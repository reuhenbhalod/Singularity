//
//  AdvancedTabView.swift
//  Singularity
//

import SwiftUI

/// Power-user tab (US-SET-7): the recent safety log, an `axdump` invoker,
/// and a factory reset. Reinforces the local-only, nothing-hidden stance —
/// the same events you can dump with `/safety log` in the shell.
struct AdvancedTabView: View {
    @Bindable var settings: SettingsStore
    @Bindable var account: AccountModel

    @State private var logs: [SafetyLogLine] = []
    @State private var confirmingReset = false
    @State private var bundleID = ""
    @State private var axOutput: String?

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
                HStack {
                    TextField("Bundle ID — e.g. com.apple.finder", text: $bundleID)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Dump AX tree") { dumpAX() }
                        .disabled(bundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let axOutput {
                    ScrollView {
                        Text(axOutput)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 140)
                    .border(.quaternary)
                }
            } header: {
                Text("Accessibility inspector")
            } footer: {
                Text("Prints a target app's Accessibility tree — the same as `axdump <bundle id>` in the shell. Requires Accessibility permission.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button("Factory Reset…", role: .destructive) { confirmingReset = true }
            } header: {
                Text("Reset")
            } footer: {
                Text("Clears all settings, saved routines, your signed-in account, and every logged-in web session. Everything is local, so this fully resets the app.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { reload() }
        .confirmationDialog(
            "Reset Singularity to defaults?", isPresented: $confirmingReset, titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                Task {
                    await FactoryReset.run(settings: settings)
                    account.signOut()
                    reload()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes: your settings, saved routines, signed-in account, and all logged-in web sessions. It can't be undone.")
        }
    }

    private func reload() {
        logs = SafetyLogReader.recent()
    }

    private func dumpAX() {
        let id = bundleID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        axOutput = AXDump.dump(bundleId: id)
    }
}
