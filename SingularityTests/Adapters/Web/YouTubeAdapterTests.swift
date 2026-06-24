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

    /// `playNewestForChannel` finds the newest video by the *stable*
    /// watch-URL shape (not a brittle id) via the shared toolkit, and
    /// returns its href (the caller navigates).
    @Test func playNewestSelectsByStableWatchURLAndReturnsHref() {
        let script = YouTubeAdapter().playNewestForChannel("MrBeast")

        // Survives lazy SPA render via the shared MutationObserver helpers.
        #expect(script.contains("MutationObserver"))
        // Returns the matched link's URL for the caller to navigate to.
        #expect(script.contains(".href"))
        // Selects by the durable URL pattern, via the shared primitive…
        #expect(script.contains("__sgl_firstLinkMatching"))
        #expect(script.contains("/watch?v="))
        // …and dismisses a consent wall first so it can't hide the grid.
        #expect(script.contains("__sgl_dismissConsent"))
        // The old brittle id selector is gone.
        #expect(!script.contains("a#video-title-link"))
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

    /// The channels-filtered search URL carries the query and YouTube's
    /// "filter: channels" token, so results resolve a name to a channel.
    @Test func channelSearchURLIsChannelsFiltered() throws {
        let url = try #require(YouTubeAdapter().channelSearchURL(for: "Marques Brownlee"))
        let string = url.absoluteString
        #expect(string.contains("www.youtube.com/results"))
        #expect(string.contains("search_query=Marques"))
        #expect(string.contains("sp=EgIQAg"))  // channels filter
    }

    /// `firstChannelHref` selects a channel result by the channel renderer
    /// / `/channel/` URL shape and returns its href.
    @Test func firstChannelHrefSelectsChannelResult() {
        let script = YouTubeAdapter().firstChannelHref()
        #expect(script.contains("ytd-channel-renderer"))
        #expect(script.contains("/channel/"))
        #expect(script.contains(".href"))
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
