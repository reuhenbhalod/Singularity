//
//  AllowlistNavigationDelegateTests.swift
//  SingularityTests
//

import Foundation
import Testing
import WebKit

@testable import Singularity

struct AllowlistNavigationDelegateTests {
    /// T-P1-05 acceptance: navigation to an on-list YouTube host is
    /// allowed.
    @Test func allowsOnListYouTubeHost() {
        let delegate = AllowlistNavigationDelegate()
        let url = URL(string: "https://www.youtube.com/@MrBeast/videos")
        #expect(delegate.decision(for: url) == .allow)
    }

    /// T-P1-05 acceptance: navigation to a host not in the adapter's
    /// allowedHosts is cancelled.
    @Test func cancelsOffListHost() {
        let delegate = AllowlistNavigationDelegate()
        let url = URL(string: "https://example.com/whatever")
        #expect(delegate.decision(for: url) == .cancel)
    }

    /// All four declared YouTube/googlevideo hosts are allowed.
    @Test func allowsEveryDeclaredHost() {
        let delegate = AllowlistNavigationDelegate()
        for host in YouTubeAdapter().allowedHosts {
            let url = URL(string: "https://\(host)/")
            #expect(delegate.decision(for: url) == .allow, "expected \(host) to be allowed")
        }
    }

    /// Host comparison is case-insensitive — `WWW.YOUTUBE.COM` must not
    /// slip through unevaluated.
    @Test func hostMatchIsCaseInsensitive() {
        let delegate = AllowlistNavigationDelegate()
        let url = URL(string: "https://WWW.YOUTUBE.COM/feed")
        #expect(delegate.decision(for: url) == .allow)
    }

    /// HTTPS is required: a non-HTTPS URL to an allowed host is still
    /// cancelled (no downgrade).
    @Test func cancelsNonHTTPSEvenForAllowedHost() {
        let delegate = AllowlistNavigationDelegate()
        for scheme in ["http", "file", "data", "javascript"] {
            let url = URL(string: "\(scheme)://www.youtube.com/")
            #expect(delegate.decision(for: url) == .cancel, "expected \(scheme) to be cancelled")
        }
    }

    /// A nil URL is cancelled rather than crashing.
    @Test func cancelsNilURL() {
        #expect(AllowlistNavigationDelegate().decision(for: nil) == .cancel)
    }

    /// T-P3-08: downloads are denied by default (nil destination).
    @Test func deniesDownloadByDefault() {
        let delegate = AllowlistNavigationDelegate(allowsDownloads: false)
        #expect(delegate.downloadDestination(suggestedFilename: "report.pdf") == nil)
    }

    /// T-P3-08: an adapter that opts in allows downloads to the
    /// Downloads folder.
    @Test func allowsDownloadWhenEnabled() {
        let delegate = AllowlistNavigationDelegate(allowsDownloads: true)
        let destination = delegate.downloadDestination(suggestedFilename: "report.pdf")
        #expect(destination?.lastPathComponent == "report.pdf")
    }
}
