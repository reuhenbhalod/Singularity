//
//  YouTubeAdapterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct YouTubeAdapterTests {
    /// T-P1-04 acceptance: the adapter declares exactly the YouTube /
    /// googlevideo hosts the web lane is allowed to drive.
    @Test func allowedHostsCoverYouTubeAndGooglevideo() {
        let adapter = YouTubeAdapter()
        #expect(
            adapter.allowedHosts == [
                "youtube.com",
                "www.youtube.com",
                "m.youtube.com",
                "googlevideo.com",
            ]
        )
    }

    /// T-P1-04 acceptance: all injected JS runs in the "singularity"
    /// content world.
    @Test func contentWorldNameIsSingularity() {
        #expect(YouTubeAdapter().contentWorldName == "singularity")
    }

    /// T-P1-04 acceptance: `playNewestForChannel` emits JS that uses a
    /// MutationObserver-based waitForSelector to find the newest video
    /// and open it (navigate to its watch page, with a click fallback).
    @Test func playNewestUsesMutationObserverAndOpensVideo() {
        let script = YouTubeAdapter().playNewestForChannel("MrBeast")

        #expect(script.contains("MutationObserver"))
        // Opens the video: navigate to its href, falling back to click.
        #expect(script.contains("location.assign"))
        #expect(script.contains(".click()"))
        // Targets the channel grid's video title links.
        #expect(script.contains("a#video-title-link"))
    }

    /// The channel argument is embedded safely as a JS string literal
    /// (no breakout) and appears in the emitted script.
    @Test func channelIsEmbeddedSafely() {
        let script = YouTubeAdapter().playNewestForChannel("MrBeast")
        #expect(script.contains("\"MrBeast\""))

        // A channel name containing a quote must not break out of the
        // literal — JSON escaping turns `"` into `\"`, so the raw
        // breakout sequence never appears.
        let tricky = YouTubeAdapter().playNewestForChannel("foo\"; alert(1);//")
        #expect(tricky.contains("\\\""))  // the escaped quote is present
        #expect(!tricky.contains("foo\";"))  // ...so the raw breakout is not
    }
}
