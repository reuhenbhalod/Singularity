//
//  SystemAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// System-level controls via AppleScript / System Events. All hooks are
/// parameterless and **safe/reversible** on purpose: `apple_script`
/// actions are not confirm-gated, so anything irreversible (e.g. emptying
/// the Trash) is deliberately left out until a per-hook risk class exists.
///
/// Controlling System Events triggers the standard Automation consent
/// prompt on first use; a denial degrades to the usual "grant it in
/// Settings" line.
struct SystemAppleScriptAdapter: AppleScriptAdapter {
    let name = "system"

    let scripts = [
        "toggle_dark_mode":
            "tell application \"System Events\" to tell appearance preferences "
            + "to set dark mode to not dark mode",
        "dark_mode_on":
            "tell application \"System Events\" to tell appearance preferences to set dark mode to true",
        "dark_mode_off":
            "tell application \"System Events\" to tell appearance preferences to set dark mode to false",
        "volume_up":
            "set volume output volume ((output volume of (get volume settings)) + 10)",
        "volume_down":
            "set volume output volume ((output volume of (get volume settings)) - 10)",
        "mute": "set volume with output muted",
        "unmute": "set volume without output muted",
        "lock_screen":
            "tell application \"System Events\" to keystroke \"q\" using {control down, command down}",
    ]
}
