//
//  KeyCombo.swift
//  Singularity
//

import Carbon.HIToolbox
import Foundation

/// A key combination suitable for global hotkey registration.
///
/// `Codable` so it can be persisted to JSON / UserDefaults for the
/// Settings rebind flow (US-SET-1). `Sendable` because `HotkeyMonitor`
/// is `@MainActor` and consumes `KeyCombo` values across actor
/// boundaries when settings change.
struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    enum Modifier: String, Codable, CaseIterable, Sendable {
        case command
        case option
        case control
        case shift

        /// Carbon modifier mask bit for this modifier.
        var carbonMask: UInt32 {
            switch self {
            case .command: return UInt32(cmdKey)
            case .option: return UInt32(optionKey)
            case .control: return UInt32(controlKey)
            case .shift: return UInt32(shiftKey)
            }
        }
    }

    let keyCode: UInt32
    let modifiers: Set<Modifier>

    /// Default shell-summon combo: ⌥Space. Mirrors the value
    /// hardcoded in AppDelegate during T-P0-03; once T-P0-08 wires
    /// the input through and Settings rebind lands, AppDelegate
    /// will read this constant instead of hardcoding the literals.
    static let defaultShellSummon = KeyCombo(
        keyCode: UInt32(kVK_Space),
        modifiers: [.option]
    )

    /// All modifiers OR'd into the single `UInt32` mask Carbon's
    /// `RegisterEventHotKey` expects.
    var carbonModifierMask: UInt32 {
        modifiers.reduce(0) { $0 | $1.carbonMask }
    }
}
