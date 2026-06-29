//
//  SpotifyWebAdapterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct SpotifyWebAdapterTests {
    /// Declares the Spotify-web hosts and an isolated data store (distinct
    /// from other adapters, so logins don't cross).
    @Test func declaresHostsAndOwnDataStore() {
        let adapter = SpotifyWebAdapter()
        #expect(adapter.allowedHosts.contains("open.spotify.com"))
        #expect(adapter.dataStoreIdentifier != YouTubeAdapter().dataStoreIdentifier)
    }

    /// The search URL percent-encodes the query for `open.spotify.com`.
    @Test func searchURLEncodesQuery() throws {
        let url = try #require(SpotifyWebAdapter().searchURL(for: "92 explorer"))
        #expect(url.absoluteString == "https://open.spotify.com/search/92%20explorer")
    }

    /// The play hook presses the first result's play button, selected by
    /// stable semantic signals (`data-testid` / `aria-label`).
    @Test func playFirstTrackClicksPlayButton() {
        let script = SpotifyWebAdapter().playFirstTrack()
        #expect(script.contains("play-button"))
        #expect(script.contains("aria-label"))
        #expect(script.contains(".click()"))
        #expect(script.contains("MutationObserver"))  // via the shared toolkit
    }
}
