//
//  SpotifyAXAdapter.swift
//  Singularity
//

import Foundation

/// Drives the Spotify desktop app via Accessibility. Phase 4 supports
/// one hook — `playpause` — by finding the transport button (whose
/// title toggles between "Play" and "Pause") and pressing it.
///
/// Note: Spotify is a CEF/Electron app, whose AX tree can be sparse;
/// if the button can't be found the lane reports it cleanly rather than
/// crashing, and a Phase-6 AppleScript path is the reliable fallback.
struct SpotifyAXAdapter: AXAdapter {
    let name = "spotify"
    let bundleID = "com.spotify.client"
    let hooks: Set<String> = ["playpause"]

    @MainActor
    func perform(_ hook: String, in app: AXApplication) throws -> String {
        switch hook {
        case "playpause":
            var button = try app.root.findFirst(role: .button, title: "Play")
            if button == nil {
                button = try app.root.findFirst(role: .button, title: "Pause")
            }
            guard let button else {
                throw AXErrors.elementUnavailable
            }
            try button.perform(.press)
            return "toggled Spotify playback"
        default:
            throw AXErrors.actionUnsupported
        }
    }
}
