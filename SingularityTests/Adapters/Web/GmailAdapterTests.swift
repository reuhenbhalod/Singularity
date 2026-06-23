//
//  GmailAdapterTests.swift
//  SingularityTests
//

import Foundation
import Testing
import WebKit

@testable import Singularity

@MainActor
struct GmailAdapterTests {
    /// T-P3-11: covers the inbox host and the Google sign-in hosts.
    @Test func allowedHostsCoverInboxAndAuth() {
        let hosts = GmailAdapter().allowedHosts
        #expect(hosts.contains("mail.google.com"))
        #expect(hosts.contains("accounts.google.com"))
    }

    /// T-P3-11: its own persistent data store, distinct from YouTube's.
    @Test func hasOwnDataStoreIdentifier() {
        #expect(GmailAdapter().dataStoreIdentifier != YouTubeAdapter().dataStoreIdentifier)
    }

    /// T-P3-11: the registry resolves Gmail by host.
    @Test func registryResolvesGmailByHost() throws {
        let adapter = try #require(AdapterRegistry().lookup(host: "mail.google.com"))
        #expect(adapter is GmailAdapter)
    }

    /// T-P3-11: "open gmail" opens a Gmail pane — the web lane builds a
    /// pane using Gmail's own data store.
    @Test func webLaneOpensGmailPane() async throws {
        let compositor = CompositorStore()
        let lane = WebLane(compositor: compositor, driver: NoopWebPaneDriver())
        let url = try #require(URL(string: "https://mail.google.com/mail/u/0/"))

        let result = try await lane.execute(PlanStep(action: .webNavigate(url)))

        #expect(result == .handled(summary: "opened mail.google.com"))
        #expect(compositor.panes.count == 1)
        guard case .web(let controller) = compositor.panes[0].kind else {
            Issue.record("expected a web pane")
            return
        }
        #expect(
            controller.webView.configuration.websiteDataStore.identifier
                == GmailAdapter().dataStoreIdentifier)
    }
}

/// No-op driver so the pane is built without touching WebKit navigation.
@MainActor
private final class NoopWebPaneDriver: WebPaneDriving {
    func navigate(_ controller: WebPaneController, to url: URL) async throws {}
    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? { nil }
}
