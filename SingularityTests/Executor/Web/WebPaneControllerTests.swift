//
//  WebPaneControllerTests.swift
//  SingularityTests
//

import Foundation
import Testing
import WebKit

@testable import Singularity

/// An adapter that opts into downloads, for the download-flag test.
private struct DownloadingAdapter: WebAdapter {
    let allowedHosts = ["downloads.example"]
    let dataStoreIdentifier = UUID()
    let allowsDownloads = true
}

@MainActor
struct WebPaneControllerTests {
    /// T-P1-07 acceptance: the web view uses the adapter's own
    /// persistent data store, identified by the adapter's UUID.
    @Test func usesAdaptersPersistentDataStore() {
        let adapter = YouTubeAdapter()
        let controller = WebPaneController(adapter: adapter)

        #expect(
            controller.webView.configuration.websiteDataStore.identifier
                == adapter.dataStoreIdentifier
        )
    }

    /// T-P1-07 acceptance: the web view's navigation delegate is the
    /// retained `AllowlistNavigationDelegate`.
    @Test func navigationDelegateIsAllowlistDelegate() {
        let controller = WebPaneController(adapter: YouTubeAdapter())

        #expect(controller.webView.navigationDelegate === controller.navigationDelegate)
        #expect(controller.webView.navigationDelegate is AllowlistNavigationDelegate)
    }

    /// T-P1-07 acceptance: downloads are denied.
    @Test func downloadsAreDenied() {
        let controller = WebPaneController(adapter: YouTubeAdapter())

        #expect(controller.navigationDelegate.allowsDownloads == false)
    }

    /// T-P3-08: an adapter that opts into downloads flows that through
    /// to the pane's delegate.
    @Test func adapterCanOptIntoDownloads() {
        let controller = WebPaneController(adapter: DownloadingAdapter())
        #expect(controller.navigationDelegate.allowsDownloads)
    }

    /// An adapter's custom User-Agent is applied to its pane; an adapter
    /// without one (YouTube) leaves WKWebView's default UA in place.
    @Test func adapterUserAgentIsApplied() {
        let spotify = WebPaneController(adapter: SpotifyWebAdapter())
        #expect(spotify.webView.customUserAgent == SpotifyWebAdapter().userAgent)
        #expect(spotify.webView.customUserAgent?.contains("Safari") == true)

        // YouTube declares no custom UA, so the pane keeps WKWebView's
        // default (nil or empty depending on the WebKit version) — and in
        // particular it is NOT a Safari-spoofing string.
        let youtube = WebPaneController(adapter: YouTubeAdapter())
        #expect((youtube.webView.customUserAgent ?? "").isEmpty)
    }

    /// The navigation delegate enforces the adapter's host allowlist.
    @Test func navigationDelegateUsesAdapterHosts() {
        let controller = WebPaneController(adapter: YouTubeAdapter())

        #expect(
            controller.navigationDelegate.decision(
                for: URL(string: "https://www.youtube.com/")
            ) == .allow
        )
        #expect(
            controller.navigationDelegate.decision(
                for: URL(string: "https://example.com/")
            ) == .cancel
        )
    }
}
