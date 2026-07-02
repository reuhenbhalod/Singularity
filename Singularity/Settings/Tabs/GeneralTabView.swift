//
//  GeneralTabView.swift
//  Singularity
//

import SwiftUI

/// The General tab (US-SET-1): summon hotkey, launch at login, appearance,
/// and the privacy stance. Hotkey changes re-register the global hotkey
/// live via a notification — no restart needed.
struct GeneralTabView: View {
    @Bindable var settings: SettingsStore
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("Shell") {
                Picker("Summon hotkey", selection: $settings.summonHotkeyID) {
                    ForEach(HotkeyPreset.allCases) { preset in
                        Text(preset.label).tag(preset.id)
                    }
                }
                .onChange(of: settings.summonHotkeyID) { _, _ in
                    NotificationCenter.default.post(name: .summonHotkeyChanged, object: nil)
                }
                Text("Summon the shell from anywhere, type a command, and press Return. Press the hotkey again or Esc to dismiss.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup & appearance") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        // Reflect the true state if the OS refuses the change.
                        launchAtLogin = LoginItem.setEnabled(enabled) ? enabled : LoginItem.isEnabled
                    }
                Picker("Appearance", selection: $settings.appearanceID) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .onChange(of: settings.appearanceID) { _, id in
                    AppAppearance.apply(id)
                }
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
