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
    /// and returns its href (the caller navigates).
    @Test func playNewestUsesMutationObserverAndReturnsHref() {
        let script = YouTubeAdapter().playNewestForChannel("MrBeast")

        #expect(script.contains("MutationObserver"))
        // Returns the matched link's URL for the caller to navigate to.
        #expect(script.contains(".href"))
        // Targets the channel grid's video title links.
        #expect(script.contains("a#video-title-link"))
    }

    /// `playCurrentVideo` waits for the video element and starts it.
    @Test func playCurrentVideoCallsPlay() {
        let script = YouTubeAdapter().playCurrentVideo()

        #expect(script.contains("MutationObserver"))
        #expect(script.contains("video.html5-main-video"))
        #expect(script.contains(".play()"))
        // Falls back to clicking the player's play button.
        #expect(script.contains("ytp-large-play-button"))
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
