//
//  SpotifyAXAdapterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct SpotifyAXAdapterTests {
    /// T-P4-05: Spotify adapter exposes the playpause hook and the right
    /// bundle ID.
    @Test func declaresPlaypauseHookAndBundle() {
        let adapter = SpotifyAXAdapter()
        #expect(adapter.name == "spotify")
        #expect(adapter.bundleID == "com.spotify.client")
        #expect(adapter.hooks.contains("playpause"))
    }
}
