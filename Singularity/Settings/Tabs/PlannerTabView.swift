//
//  PlannerTabView.swift
//  Singularity
//

import SwiftUI

/// Loads the installed model list from `GET /api/tags` at the configured
/// base URL (T-P7-12). On failure the tab falls back to free-text entry.
@MainActor
@Observable
final class PlannerModelsLoader {
    private(set) var models: [String] = []
    private(set) var reachable = true

    func load(baseURLString: String) async {
        guard let url = URL(string: baseURLString) else {
            models = []
            reachable = false
            return
        }
        do {
            models = try await OllamaClient(baseURL: url).tags()
            reachable = true
        } catch {
            models = []
            reachable = false
        }
    }
}

/// The Planner tab (US-SET-2): the local model, Ollama endpoint, and
/// timeout. Bound to `SettingsStore`; changes take effect on the next
/// command.
struct PlannerTabView: View {
    @Bindable var settings: SettingsStore
    @State private var loader = PlannerModelsLoader()

    var body: some View {
        Form {
            Section("Local model (Ollama)") {
                if loader.models.isEmpty {
                    TextField("Model", text: $settings.plannerModel)
                        .autocorrectionDisabled()
                } else {
                    Picker("Model", selection: $settings.plannerModel) {
                        // Keep the current selection visible even if it's not
                        // in the installed list (e.g. a typo or a pulled model).
                        if !loader.models.contains(settings.plannerModel) {
                            Text(settings.plannerModel).tag(settings.plannerModel)
                        }
                        ForEach(loader.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                TextField("Ollama URL", text: $settings.ollamaBaseURL)
                    .autocorrectionDisabled()
                Stepper(
                    "Timeout: \(settings.plannerTimeoutSec)s",
                    value: $settings.plannerTimeoutSec, in: 5...120, step: 5)
                Button("Reload models") {
                    Task { await loader.load(baseURLString: settings.ollamaBaseURL) }
                }
            }

            Section {
                if loader.reachable {
                    Text("Intent parsing runs on your local Ollama. Changes apply to your next command.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Couldn't reach Ollama at that URL — type the model name above. Is `ollama serve` running?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await loader.load(baseURLString: settings.ollamaBaseURL) }
    }
}
