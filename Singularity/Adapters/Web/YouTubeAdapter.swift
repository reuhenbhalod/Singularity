//
//  YouTubeAdapter.swift
//  Singularity
//

import Foundation

/// Lane-2 driver for YouTube. Phase 1 supports exactly one hook —
/// `play_newest` — which clicks the most recent video on a channel's
/// `/videos` page (the grid is newest-first by default, so the first
/// tile is the newest upload).
///
/// The hero pipeline is two steps: a `webNavigate` to
/// `https://www.youtube.com/@<channel>/videos` (handled by the web
/// lane), then this hook to click the first video. The JS runs in the
/// `"singularity"` content world so its helpers never collide with
/// YouTube's own globals and the page's CSP does not apply to it
/// (research brief §4).
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

    /// JavaScript that waits for the channel's video grid to render,
    /// then clicks the first (newest) video link.
    ///
    /// Returns a body suitable for `WKWebView.callAsyncJavaScript`,
    /// which wraps it in an `async` function — so it may `await` and
    /// `return`. It defines a `MutationObserver`-based `waitForSelector`
    /// inline (the reusable Swift-side bridge arrives in T-P1-06) so the
    /// click survives YouTube's lazy SPA render: the grid tiles appear
    /// well after `didFinish`.
    ///
    /// - Parameter channel: the channel handle (e.g. `"MrBeast"`),
    ///   embedded only as a diagnostic marker — navigation to the
    ///   channel page is the web lane's job (the preceding
    ///   `webNavigate` step), so this hook just clicks what's there.
    func playNewestForChannel(_ channel: String) -> String {
        let channelLiteral = Self.jsStringLiteral(channel)
        // Title links in the grid: `a#video-title-link` is the modern
        // markup; the others are fallbacks across YouTube layouts.
        let selector = "a#video-title-link, a#video-title, ytd-rich-grid-media a#thumbnail"
        let selectorLiteral = Self.jsStringLiteral(selector)
        return """
            const __sgl_channel = \(channelLiteral);
            const __sgl_selector = \(selectorLiteral);
            console.log("[singularity] play_newest for channel " + __sgl_channel);

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

            const __sgl_link = await __sgl_waitForSelector(__sgl_selector, 10000);
            __sgl_link.click();
            return __sgl_link.href || true;
            """
    }

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
