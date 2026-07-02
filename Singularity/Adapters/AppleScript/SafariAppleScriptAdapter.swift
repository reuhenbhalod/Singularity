//
//  SafariAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Reads Safari's front tab via AppleScript (research brief §6).
struct SafariAppleScriptAdapter: AppleScriptAdapter {
    let name = "safari"

    let scripts = [
        "current_url":
            "tell application \"Safari\"\n"
            + "if (count of windows) is 0 then return \"No Safari window is open\"\n"
            + "return URL of current tab of front window\n"
            + "end tell",
        "current_title":
            "tell application \"Safari\"\n"
            + "if (count of windows) is 0 then return \"No Safari window is open\"\n"
            + "return name of current tab of front window\n"
            + "end tell",
    ]
}
