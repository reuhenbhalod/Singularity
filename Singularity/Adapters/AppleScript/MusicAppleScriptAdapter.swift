//
//  MusicAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Controls the Apple Music desktop app via AppleScript (research brief
/// §6). Playback control through the app's scripting dictionary is a
/// structured API — far more reliable than driving its UI.
struct MusicAppleScriptAdapter: AppleScriptAdapter {
    let name = "music"

    let scripts = [
        "playpause": "tell application \"Music\" to playpause",
        "play": "tell application \"Music\" to play",
        "pause": "tell application \"Music\" to pause",
        "next": "tell application \"Music\" to next track",
        "previous": "tell application \"Music\" to previous track",
        "current":
            "tell application \"Music\"\n"
            + "if player state is playing then\n"
            + "return (name of current track) & \" — \" & (artist of current track)\n"
            + "else\n"
            + "return \"Music isn't playing\"\n"
            + "end if\n"
            + "end tell",
    ]
}
