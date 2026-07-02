//
//  PlannerTabView.swift
//  Singularity
//

import SwiftUI

/// The Planner tab (US-SET-2): the local model, Ollama endpoint, and
/// timeout. Bound to `SettingsStore`; changes take effect on the next
/// command.
struct PlannerTabView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Local model (Ollama)") {
                TextField("Model", text: $settings.plannerModel)
                    .autocorrectionDisabled()
                TextField("Ollama URL", text: $settings.ollamaBaseURL)
                    .autocorrectionDisabled()
                Stepper(
                    "Timeout: \(settings.plannerTimeoutSec)s",
                    value: $settings.plannerTimeoutSec, in: 5...120, step: 5)
            }

            Section {
                Text("Intent parsing runs on your local Ollama. Changes apply to your next command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
