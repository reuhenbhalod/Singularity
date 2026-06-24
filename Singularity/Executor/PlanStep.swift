//
//  PlanStep.swift
//  Singularity
//

import Foundation

/// One step of a plan: the action to perform, plus metadata (risk class
/// set by `PlanValidator` in Phase 5, etc.).
struct PlanStep: Codable, Equatable {
    let action: Action

    /// Whether a web navigation should open a NEW pane instead of reusing
    /// the current one. Defaults to `false`: same-site navigations reuse
    /// the open pane (so "play another video" replaces in place rather
    /// than opening a new tab). The planner sets it `true` only when the
    /// user explicitly asks for a new tab/window or to keep the current
    /// pane open alongside. On the wire it is the optional `new_pane`
    /// field; absent means `false`.
    var newPane: Bool = false

    init(action: Action, newPane: Bool = false) {
        self.action = action
        self.newPane = newPane
    }

    private enum CodingKeys: String, CodingKey {
        case action
        case newPane = "new_pane"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(Action.self, forKey: .action)
        newPane = try container.decodeIfPresent(Bool.self, forKey: .newPane) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        // Only emit when set, so existing round-trip fixtures (which omit
        // it) stay byte-stable.
        if newPane {
            try container.encode(newPane, forKey: .newPane)
        }
    }
}
