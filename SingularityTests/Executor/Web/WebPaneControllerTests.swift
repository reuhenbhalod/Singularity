//
//  WebPaneControllerTests.swift
//  SingularityTests
//

import Foundation
import Testing
import WebKit

@testable import Singularity

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
