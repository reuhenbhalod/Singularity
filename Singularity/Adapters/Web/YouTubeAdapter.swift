//
//  YouTubeAdapter.swift
//  Singularity
//

import Foundation

/// Lane-2 driver for YouTube. Phase 1 supports the hero flow: find the
/// newest video on a channel's `/videos` page (the grid is newest-first
/// by default, so the first tile is the newest upload) and start it
/// playing on the watch page.
///
/// The hero pipeline: a `webNavigate` to
/// `https://www.youtube.com/@<channel>/videos`, then `playNewestForChannel`
/// returns the newest video's URL (the router navigates to it), then
/// `playCurrentVideo` starts playback. All JS runs in the `"singularity"`
/// content world so its helpers never collide with YouTube's own globals
/// and the page's CSP does not apply to it (research brief §4).
struct YouTubeAdapter: WebAdapter {
    let allowedHosts = [
        "youtube.com",
        "www.youtube.com",
        "m.youtube.com",
        "googlevideo.com",
    ]

    /// Named `WKContentWorld` for all of this adapter's injected JS.
    /// Phase 3 promotes this to a `WebAdapter` protocol requirement.
    let contentWorldName = "singularity"

    /// Fixed identifier for YouTube's isolated, persistent data store —
    /// a hardcoded constant so the logged-in session survives cold
    /// launches (the hero command requires persistent login).
    let dataStoreIdentifier =
        UUID(uuidString: "B6F2D3E1-7A4C-4E9B-9F12-3C5D6E7A8B90") ?? UUID()

    /// JavaScript that waits for the channel's video grid to render and
    /// returns the newest video's absolute watch URL (or `""` if none).
    ///
    /// Returns a body suitable for `WKWebView.callAsyncJavaScript`,
    /// which wraps it in an `async` function — so it may `await` and
    /// `return`. It composes the shared `WebHookJS` toolkit so it
    /// survives YouTube's lazy SPA render: the grid tiles appear well
    /// after `didFinish`. The caller navigates to the returned URL —
    /// driving `location` from an isolated content world does not
    /// reliably navigate the page.
    ///
    /// Robustness: the newest upload is found by the *stable* shape of a
    /// video link (its `href` contains `/watch?v=`), not by a generated
    /// id like `a#video-title-link` that a YouTube redesign renames. The
    /// `/videos` grid is newest-first, so the first such link in document
    /// order is the newest upload. A consent wall, if present, is
    /// dismissed first so it can't hide the grid.
    ///
    /// - Parameter channel: the channel handle (e.g. `"MrBeast"`),
    ///   embedded only as a diagnostic marker — navigation to the
    ///   channel page is the web lane's job (the preceding
    ///   `webNavigate` step).
    func playNewestForChannel(_ channel: String) -> String {
        let channelLiteral = WebHookJS.jsStringLiteral(channel)
        let watchNeedle = WebHookJS.jsStringLiteral("/watch?v=")
        return """
            \(WebHookJS.library)
            const __sgl_channel = \(channelLiteral);
            console.log("[singularity] play_newest for channel " + __sgl_channel);
            __sgl_dismissConsent();
            // Find the newest video by the durable URL shape, not a
            // brittle id. The caller (Swift) performs the navigation —
            // driving location from an isolated content world doesn't
            // reliably navigate the page.
            const __sgl_link = await __sgl_firstLinkMatching(\(watchNeedle), 15000);
            return __sgl_link ? (__sgl_link.href || "") : "";
            """
    }

    /// JavaScript that starts the current watch page's video playing.
    ///
    /// The watch page often loads paused (autoplay isn't reliable after
    /// a programmatic navigation), so this waits for the `<video>`
    /// element, calls `play()`, and falls back to clicking YouTube's
    /// play button if it's still paused. Returns `"playing"` / `"paused"`.
    func playCurrentVideo() -> String {
        """
        \(WebHookJS.library)
        __sgl_dismissConsent();
        const __sgl_video = await __sgl_waitForSelector("video.html5-main-video, video", 15000)
            .catch(() => null);
        if (!__sgl_video) { return "no-video"; }
        const __sgl_clickPlay = () => {
            const b = document.querySelector(".ytp-play-button, .ytp-large-play-button");
            const label = b ? (b.getAttribute("aria-label") || "") : "";
            // Only click when the button means "Play" (not "Pause") so we
            // never toggle an already-running video back to paused.
            if (b && /play/i.test(label) && !/pause/i.test(label)) {
                try { b.click(); } catch (e) {}
            }
        };
        // Poll for ~12s: try programmatic play(), then the player's own
        // button, until playback is actually advancing. Survives a
        // not-yet-ready player, autoplay blocks, and pre-roll ad handoff —
        // the old single attempt only worked when the player happened to be
        // ready the instant the hook ran.
        for (let __sgl_i = 0; __sgl_i < 30; __sgl_i++) {
            try { await __sgl_video.play(); } catch (e) {}
            if (__sgl_video.paused) { __sgl_clickPlay(); }
            await __sgl_sleep(400);
            if (!__sgl_video.paused && __sgl_video.currentTime > 0) { return "playing"; }
        }
        return __sgl_video.paused ? "paused" : "playing";
        """
    }

    /// A channels-filtered YouTube search URL for a creator name. Used to
    /// resolve a name to its real channel when a guessed `@handle` misses
    /// (e.g. "Marques Brownlee" → `@mkbhd`): YouTube's own search is the
    /// reliable name→channel resolver. The `sp=EgIQAg==` token is YouTube's
    /// "filter: channels" parameter, so every result is a channel.
    func channelSearchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/results"
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query),
            URLQueryItem(name: "sp", value: "EgIQAg=="),
        ]
        return components.url
    }

    /// JS that returns the first channel result's URL on a YouTube search
    /// page (or `""`). Channel results link to `/@handle` or
    /// `/channel/UC…`; this selects them by the channel renderer / that
    /// stable URL shape rather than a generated id.
    func firstChannelHref() -> String {
        """
        \(WebHookJS.library)
        const __sgl_el = await __sgl_waitForSelector(
            'ytd-channel-renderer a[href], a[href*="/channel/"]', 12000).catch(() => null);
        return (__sgl_el && __sgl_el.href) ? __sgl_el.href : "";
        """
    }
}
