//
//  HotkeyPreset.swift
//  Singularity
//

import Carbon.HIToolbox
import Foundation

/// The summon-hotkey choices offered in the General tab (US-SET-1). A small
/// curated set of conflict-unlikely combos keeps rebinding to a picker,
/// which needs no NSEvent-capture recorder and can't produce an
/// unregisterable combo. Persisted by `id` in `SettingsStore`.
enum HotkeyPreset: String, CaseIterable, Identifiable {
    case optionSpace = "opt-space"
    case controlSpace = "ctrl-space"
    case commandShiftSpace = "cmd-shift-space"
    case optionBacktick = "opt-backtick"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .optionSpace: return "⌥ Space"
        case .controlSpace: return "⌃ Space"
        case .commandShiftSpace: return "⌘ ⇧ Space"
        case .optionBacktick: return "⌥ `"
        }
    }

    var combo: KeyCombo {
        switch self {
        case .optionSpace:
            return KeyCombo(keyCode: UInt32(kVK_Space), modifiers: [.option])
        case .controlSpace:
            return KeyCombo(keyCode: UInt32(kVK_Space), modifiers: [.control])
        case .commandShiftSpace:
            return KeyCombo(keyCode: UInt32(kVK_Space), modifiers: [.command, .shift])
        case .optionBacktick:
            return KeyCombo(keyCode: UInt32(kVK_ANSI_Grave), modifiers: [.option])
        }
    }

    static func preset(id: String) -> HotkeyPreset {
        HotkeyPreset(rawValue: id) ?? .optionSpace
    }
}

extension Notification.Name {
    /// Posted when the summon-hotkey preset changes, so AppDelegate can
    /// re-register the global hotkey live — no restart needed.
    static let summonHotkeyChanged = Notification.Name("SingularitySummonHotkeyChanged")
}
