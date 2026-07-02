//
//  SafetyTabView.swift
//  Singularity
//

import SwiftUI

/// The Safety tab of Settings (US-SET-3): NSFW toggle, Touch ID grace,
/// panic phrase, and a read-only allowlist viewer. Bound to
/// `SettingsStore`; changes take effect immediately. Built now (Phase 5)
/// so the settings surface exists — it's hosted by the Settings scene in
/// Phase 7 (T-P7-10).
struct SafetyTabView: View {
    @Bindable var settings: SettingsStore

    private let allowedHosts = AllowedDomains().all.sorted()

    var body: some View {
        Form {
            Section("Content") {
                Toggle("Block adult content (NSFW)", isOn: $settings.nsfwFilterEnabled)
                Text(
                    "This adds NSFW domain blocking on top of the executor's existing safety "
                        + "rules. Turning it off does not allow any new sites."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Authentication") {
                Stepper(
                    "Touch ID grace: \(settings.touchIDGraceSeconds)s",
                    value: $settings.touchIDGraceSeconds, in: 0...300, step: 15)
            }

            Section("Panic phrase") {
                TextField("Panic phrase", text: $settings.panicPhrase)
                    .autocorrectionDisabled()
            }

            Section("Allowed sites (read-only)") {
                if allowedHosts.isEmpty {
                    Text("No sites yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(allowedHosts, id: \.self) { host in
                        Text(host).font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
