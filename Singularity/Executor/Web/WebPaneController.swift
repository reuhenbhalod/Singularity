//
//  WebPaneController.swift
//  Singularity
//

import Foundation
import WebKit

/// Owns the `WKWebView` for one web pane and wires it to an adapter.
///
/// Each pane gets the adapter's own **persistent** `WKWebsiteDataStore`
/// (keyed by the adapter's `dataStoreIdentifier`) so a logged-in
/// session — YouTube, Gmail — survives cold launches and stays isolated
/// from other adapters (brief §11.5). The single
/// `AllowlistNavigationDelegate` enforces the host allowlist and denies
/// downloads (brief §4); it is retained here because `WKWebView` holds
/// its `navigationDelegate` weakly.
///
/// `@MainActor` because `WKWebView` and its configuration are
/// main-actor-bound.
@MainActor
final class WebPaneController {
    let webView: WKWebView

    /// Retained so the web view's weak `navigationDelegate` stays alive.
    let navigationDelegate: AllowlistNavigationDelegate

    private let adapter: any WebAdapter

    init(adapter: any WebAdapter) {
        self.adapter = adapter

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(
            forIdentifier: adapter.dataStoreIdentifier
        )
        // Let the page autoplay video without a real click gesture —
        // the user explicitly asked to play, so a programmatic click on
        // the newest video should start playback.
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        // The nav delegate consults the central URLPolicy (the union of
        // all adapters' allowed hosts), not just this adapter's.
        // Downloads follow the adapter's own opt-in.
        let navigationDelegate = AllowlistNavigationDelegate(allowsDownloads: adapter.allowsDownloads)
        webView.navigationDelegate = navigationDelegate

        self.webView = webView
        self.navigationDelegate = navigationDelegate
    }

    /// How long to wait for `didFinish` before proceeding anyway. A
    /// page like YouTube can keep network activity alive; the adapter
    /// hook's own `waitForSelector` handles "is the content ready",
    /// so a slow `didFinish` must not block the hook from running.
    private static let loadTimeout: TimeInterval = 12

    /// Navigates the pane to `url` and returns once the load finishes,
    /// throwing only if it fails outright. Bridges the navigation
    /// delegate's `didFinish`/`didFail` callbacks into an `async`
    /// continuation; whichever of {finish, fail, timeout} fires first
    /// resumes it exactly once. A timeout resolves successfully so the
    /// following hook still gets to run against the (rendering) page.
    func load(_ url: URL) async throws {
        let resumed = Resumed()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            navigationDelegate.onDidFinish = {
                guard !resumed.value else { return }
                resumed.value = true
                cont.resume()
            }
            navigationDelegate.onDidFail = { error in
                guard !resumed.value else { return }
                resumed.value = true
                cont.resume(throwing: error)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.loadTimeout * 1_000_000_000))
                guard !resumed.value else { return }
                resumed.value = true
                cont.resume()
            }
            webView.load(URLRequest(url: url))
        }
    }

    /// Runs an adapter hook's `javaScript` in the adapter's content
    /// world (so it can't collide with the page or be blocked by CSP)
    /// and returns whatever the script resolves to.
    @discardableResult
    func evaluate(_ javaScript: String) async throws -> Any? {
        try await webView.callAsyncJavaScript(
            javaScript,
            arguments: [:],
            contentWorld: .singularity
        )
    }

    /// Single-resume guard for the load continuation.
    private final class Resumed {
        var value = false
    }
}
