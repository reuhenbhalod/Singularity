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
