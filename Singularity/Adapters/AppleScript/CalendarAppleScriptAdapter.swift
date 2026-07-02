//
//  CalendarAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Reads the Calendar app via AppleScript (research brief §6). Read-only;
/// Calendar scripting is notoriously slow, so hooks stay minimal.
struct CalendarAppleScriptAdapter: AppleScriptAdapter {
    let name = "calendar"

    let scripts = [
        "calendar_count": "tell application \"Calendar\" to return (count of calendars) & \" calendars\"",
    ]
}
