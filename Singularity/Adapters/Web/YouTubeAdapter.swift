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
    /// `return`. It defines a `MutationObserver`-based `waitForSelector`
    /// inline (the reusable Swift-side bridge arrives in T-P1-06) so it
    /// survives YouTube's lazy SPA render: the grid tiles appear well
    /// after `didFinish`. The caller navigates to the returned URL —
    /// driving `location` from an isolated content world does not
    /// reliably navigate the page.
    ///
    /// - Parameter channel: the channel handle (e.g. `"MrBeast"`),
    ///   embedded only as a diagnostic marker — navigation to the
    ///   channel page is the web lane's job (the preceding
    ///   `webNavigate` step).
    func playNewestForChannel(_ channel: String) -> String {
        let channelLiteral = Self.jsStringLiteral(channel)
        // Title links in the grid: `a#video-title-link` is the modern
        // markup; the others are fallbacks across YouTube layouts.
        let selector = "a#video-title-link, a#video-title, ytd-rich-grid-media a#thumbnail"
        let selectorLiteral = Self.jsStringLiteral(selector)
        return """
            \(Self.waitForSelectorJS)
            const __sgl_channel = \(channelLiteral);
            console.log("[singularity] play_newest for channel " + __sgl_channel);
            const __sgl_link = await __sgl_waitForSelector(\(selectorLiteral), 10000);
            // Return the newest video's absolute watch URL. The caller
            // (Swift) performs the navigation — driving location from an
            // isolated content world doesn't reliably navigate the page.
            return __sgl_link.href || "";
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
        \(Self.waitForSelectorJS)
        const __sgl_video = await __sgl_waitForSelector("video.html5-main-video, video", 10000);
        try { await __sgl_video.play(); } catch (e) {}
        if (__sgl_video.paused) {
            const __sgl_btn = document.querySelector(".ytp-large-play-button, .ytp-play-button");
            if (__sgl_btn) { __sgl_btn.click(); }
        }
        return __sgl_video.paused ? "paused" : "playing";
        """
    }

    /// Shared `MutationObserver`-based `waitForSelector` helper, prepended
    /// to each hook's body. Resolves with the first element matching the
    /// selector once it appears, or rejects after `timeoutMs` — so a hook
    /// survives YouTube's lazy SPA render (content appears after
    /// `didFinish`).
    private static let waitForSelectorJS = """
        function __sgl_waitForSelector(selector, timeoutMs) {
            return new Promise((resolve, reject) => {
                const existing = document.querySelector(selector);
                if (existing) { resolve(existing); return; }
                const observer = new MutationObserver(() => {
                    const el = document.querySelector(selector);
                    if (el) { observer.disconnect(); resolve(el); }
                });
                observer.observe(document.documentElement, { childList: true, subtree: true });
                setTimeout(() => {
                    observer.disconnect();
                    reject(new Error("timeout waiting for " + selector));
                }, timeoutMs);
            });
        }
        """

    /// Encodes a Swift string as a JavaScript string literal (quoted
    /// and escaped) by reusing JSON's string grammar, which is a strict
    /// subset of JS string syntax. Prevents a channel name with quotes
    /// or backslashes from breaking out of the literal.
    private static func jsStringLiteral(_ value: String) -> String {
        // JSON-encoding a bare String yields a valid, escaped JS string
        // literal. Encoding a String cannot realistically fail; fall
        // back to an empty literal rather than throwing from a hook.
        guard let data = try? JSONEncoder().encode(value),
            let literal = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return literal
    }
}
