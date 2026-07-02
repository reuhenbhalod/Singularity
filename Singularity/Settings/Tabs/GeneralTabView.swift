//
//  GeneralTabView.swift
//  Singularity
//

import SwiftUI

/// The General tab. Hotkey rebinding and launch-at-login land in a later
/// update; for now it shows the shell basics and the privacy stance.
struct GeneralTabView: View {
    var body: some View {
        Form {
            Section("Shell") {
                LabeledContent("Summon hotkey", value: "⌥ Space")
                Text("Summon the shell from anywhere, type a command, and press Return. Press the hotkey again or Esc to dismiss.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text(
                    "Singularity runs entirely on your Mac. There is no cloud backend, no "
                        + "telemetry, and no memory — nothing you do is stored across sessions "
                        + "or synced anywhere."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
