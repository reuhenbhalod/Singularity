//
//  FinderAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Reads Finder state via AppleScript (research brief §6). Read-only
/// operations — reporting the selection or the front window's path.
struct FinderAppleScriptAdapter: AppleScriptAdapter {
    let name = "finder"

    let scripts = [
        "selection_count": "tell application \"Finder\" to return count of (get selection)",
        "front_path":
            "tell application \"Finder\"\n"
            + "if (count of Finder windows) is 0 then return \"No Finder window is open\"\n"
            + "return POSIX path of (target of front Finder window as alias)\n"
            + "end tell",
    ]
}
