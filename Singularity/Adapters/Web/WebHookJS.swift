//
//  WebHookJS.swift
//  Singularity
//

import Foundation

/// Shared JavaScript toolkit that every web adapter composes into its
/// hooks. It is the reusable robustness layer behind the "lanes over
/// codegen" design: adapters still own *what* to do on a given site, but
/// they should do it through these primitives instead of hand-rolling
/// fragile DOM queries.
///
/// The guiding rule — and the reason the YouTube hero flow broke once —
/// is **select by stable semantic signal, never by generated id/class
/// names**. Sites rename `#video-title-link` on a redesign, but the
/// *shape* of a link ("points at `/watch?v=`"), an element's ARIA role,
/// or its visible text are far more durable. `firstLinkMatching` and
/// `clickByText` encode that rule so any adapter inherits it.
///
/// Every helper is defined as a `__sgl_`-prefixed function so it cannot
/// collide with the page's own globals (they also run in the isolated
/// `singularity` `WKContentWorld`). An adapter prepends `library` to its
/// hook body and then calls the helpers; the body is wrapped by
/// `callAsyncJavaScript` in an `async` function, so top-level `await` and
/// `return` are valid.
enum WebHookJS {
    /// The full set of helper definitions, prepended to a hook body.
    ///
    /// - `__sgl_waitForSelector(selector, timeoutMs)` — resolves with the
    ///   first element matching a CSS selector once it appears (or
    ///   rejects on timeout). Survives lazy SPA render via
    ///   `MutationObserver` (the grid/inbox appears after `didFinish`).
    /// - `__sgl_firstLinkMatching(hrefNeedle, timeoutMs)` — resolves with
    ///   the first `<a>` whose resolved `href` contains `hrefNeedle`, in
    ///   document order, or `null` on timeout. Gently auto-scrolls to
    ///   trigger lazy-loaded lists. This is the durable replacement for
    ///   id-based link selection.
    /// - `__sgl_clickByText(selector, text)` — clicks the first element
    ///   matching `selector` whose visible text / aria-label contains
    ///   `text` (case-insensitive). Returns whether it clicked.
    /// - `__sgl_dismissConsent()` — best-effort: clicks a common
    ///   cookie/consent "accept" control so a wall doesn't hide content.
    static let library = """
        function __sgl_waitForSelector(selector, timeoutMs) {
            return new Promise((resolve, reject) => {
                const existing = document.querySelector(selector);
                if (existing) { resolve(existing); return; }
                const observer = new MutationObserver(() => {
                    const el = document.querySelector(selector);
                    if (el) { observer.disconnect(); clearTimeout(timer); resolve(el); }
                });
                observer.observe(document.documentElement, { childList: true, subtree: true });
                const timer = setTimeout(() => {
                    observer.disconnect();
                    reject(new Error("timeout waiting for " + selector));
                }, timeoutMs);
            });
        }
        function __sgl_firstLinkMatching(hrefNeedle, timeoutMs) {
            const find = () => {
                const anchors = document.querySelectorAll("a[href]");
                for (const a of anchors) {
                    if ((a.href || "").indexOf(hrefNeedle) !== -1) { return a; }
                }
                return null;
            };
            return new Promise((resolve) => {
                let settled = false;
                const finish = (el) => {
                    if (settled) { return; }
                    settled = true;
                    observer.disconnect();
                    clearTimeout(timer);
                    clearInterval(scroller);
                    resolve(el);
                };
                const hit = find();
                if (hit) { resolve(hit); return; }
                const observer = new MutationObserver(() => {
                    const el = find();
                    if (el) { finish(el); }
                });
                observer.observe(document.documentElement, { childList: true, subtree: true });
                // Nudge lazy-loaded lists/grids into rendering.
                const scroller = setInterval(() => {
                    window.scrollBy(0, Math.max(400, window.innerHeight * 0.8));
                }, 500);
                const timer = setTimeout(() => { finish(null); }, timeoutMs);
            });
        }
        function __sgl_clickByText(selector, text) {
            const needle = (text || "").trim().toLowerCase();
            const els = document.querySelectorAll(selector);
            for (const el of els) {
                const label = (el.innerText || el.textContent || el.getAttribute("aria-label") || "")
                    .trim().toLowerCase();
                if (label && label.indexOf(needle) !== -1) {
                    try { el.click(); return true; } catch (e) {}
                }
            }
            return false;
        }
        function __sgl_dismissConsent() {
            const phrases = ["accept all", "i agree", "agree to all", "accept the use of cookies",
                "accept cookies", "allow all", "accept"];
            for (const phrase of phrases) {
                if (__sgl_clickByText("button, [role=\\"button\\"], a", phrase)) { return true; }
            }
            return false;
        }
        function __sgl_sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
        """

    /// Encodes a Swift string as a JavaScript string literal (quoted and
    /// escaped) by reusing JSON's string grammar, which is a strict
    /// subset of JS string syntax. Prevents a value with quotes or
    /// backslashes from breaking out of the literal — the safe way to
    /// embed a channel name, search term, or URL fragment into a hook.
    static func jsStringLiteral(_ value: String) -> String {
        // JSON-encoding a bare String yields a valid, escaped JS string
        // literal. `withoutEscapingSlashes` keeps `/` as `/` (JSON would
        // otherwise emit `\/`) so embedded URL fragments like "/watch?v="
        // read cleanly in the generated script. Encoding a String cannot
        // realistically fail; fall back to an empty literal rather than
        // throwing from a hook.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        guard let data = try? encoder.encode(value),
            let literal = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return literal
    }
}
