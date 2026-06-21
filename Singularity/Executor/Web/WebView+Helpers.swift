//
//  WebView+Helpers.swift
//  Singularity
//

import Foundation
import WebKit

/// Errors thrown by the `WKWebView` driving helpers.
enum WebViewHelperError: Error {
    /// The selector never appeared before the timeout, or the wait
    /// script otherwise failed to run. Carries the selector and the
    /// underlying error (the JS rejection or a WebKit failure).
    case waitForSelectorFailed(selector: String, underlying: any Error)
}

extension WKContentWorld {
    /// The named isolated world every Singularity adapter's JS runs in
    /// (research brief §4). Keeping our helpers off the page's global
    /// scope means our globals never collide with the site's, and the
    /// page's CSP does not apply to scripts we inject here.
    static let singularity = WKContentWorld.world(name: "singularity")
}

@MainActor
extension WKWebView {
    /// Suspends until an element matching `selector` exists in the DOM,
    /// or throws once `timeout` elapses.
    ///
    /// This is the universal "is the SPA ready?" primitive from brief
    /// §4: `WKNavigationDelegate.didFinish` only signals the initial
    /// document load, not the app's actual content render (the YouTube
    /// grid, the Gmail inbox). The injected script resolves immediately
    /// if the element is already present, otherwise it watches the DOM
    /// with a `MutationObserver` and resolves the moment the element
    /// appears. The observer sees page-world mutations because the DOM
    /// is shared across content worlds — only JS globals are isolated.
    ///
    /// `selector` and the timeout are passed as `callAsyncJavaScript`
    /// arguments rather than string-interpolated, so a selector can
    /// never break out of the script body.
    ///
    /// - Parameters:
    ///   - selector: a CSS selector to wait for.
    ///   - timeout: how long to wait before failing. Default 10s.
    ///   - contentWorld: the world to run in. Default `.singularity`.
    func waitForSelector(
        _ selector: String,
        timeout: TimeInterval = 10,
        in contentWorld: WKContentWorld = .singularity
    ) async throws {
        // Resolves with a string (not a bare boolean / undefined) so the
        // value bridges cleanly back through `callAsyncJavaScript`, which
        // errors on unsupported return types.
        let body = """
            return await new Promise((resolve, reject) => {
                if (document.querySelector(selector)) { resolve("found"); return; }
                const observer = new MutationObserver(() => {
                    if (document.querySelector(selector)) {
                        observer.disconnect();
                        clearTimeout(timer);
                        resolve("found");
                    }
                });
                observer.observe(document.documentElement, { childList: true, subtree: true });
                const timer = setTimeout(() => {
                    observer.disconnect();
                    reject(new Error("waitForSelector timed out: " + selector));
                }, timeoutMs);
            });
            """
        do {
            _ = try await callAsyncJavaScript(
                body,
                arguments: ["selector": selector, "timeoutMs": timeout * 1000],
                contentWorld: contentWorld
            )
        } catch {
            throw WebViewHelperError.waitForSelectorFailed(selector: selector, underlying: error)
        }
    }
}
