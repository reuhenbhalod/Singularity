//
//  SpotifyWebAdapter.swift
//  Singularity
//

import Foundation

/// Lane-2 driver for the Spotify **web** player (`open.spotify.com`),
/// used to play a *specific* song by name — the native `SpotifyAXAdapter`
/// only toggles play/pause. The flow mirrors YouTube: navigate to the
/// search page for the song, then press the first result's play button.
///
/// Playing a full track requires the user to be logged into Spotify in
/// the pane; the per-adapter persistent `WKWebsiteDataStore` keeps that
/// login across launches. Like every web adapter, the play-button
/// selector targets stable semantic signals (`data-testid`, the
/// `aria-label`) rather than Spotify's generated class names.
struct SpotifyWebAdapter: WebAdapter {
    let allowedHosts = [
        "open.spotify.com",
        "accounts.spotify.com",
        "www.spotify.com",
        "spotify.com",
    ]

    let contentWorldName = "singularity"

    /// Fixed identifier for Spotify-web's isolated, persistent data store
    /// so the logged-in session survives cold launches.
    let dataStoreIdentifier =
        UUID(uuidString: "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D") ?? UUID()

    /// The Spotify-web search URL for a song/artist query.
    func searchURL(for query: String) -> URL? {
        let encoded =
            query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return URL(string: "https://open.spotify.com/search/\(encoded)")
    }

    /// JS that presses the first play button on the page (the top search
    /// result) and reports `"playing"`, or `""` if none appeared. Runs in
    /// the isolated `singularity` content world.
    func playFirstTrack() -> String {
        """
        \(WebHookJS.library)
        __sgl_dismissConsent();
        const __sgl_btn = await __sgl_waitForSelector(
            '[data-testid="play-button"], button[aria-label^="Play"]', 15000).catch(() => null);
        if (__sgl_btn) { __sgl_btn.click(); return "playing"; }
        return "";
        """
    }
}
