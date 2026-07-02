//
//  RemindersAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Reads the Reminders app via AppleScript (research brief §6). Read-only;
/// Reminders scripting can be slow on large lists.
struct RemindersAppleScriptAdapter: AppleScriptAdapter {
    let name = "reminders"

    let scripts = [
        "count":
            "tell application \"Reminders\" to return "
            + "(count of (reminders whose completed is false)) & \" open reminders\"",
    ]
}
