//
//  AllowlistNavigationDelegate.swift
//  Singularity
//

import Foundation
import WebKit

/// `WKNavigationDelegate` that refuses to let a web pane navigate
/// anywhere outside a fixed host allowlist (research brief §11.4).
///
/// Phase 1 is hardcoded to the YouTube adapter's `allowedHosts`: the
/// hero command only ever drives YouTube, and wiring the central
/// `Safety/AllowedDomains` registry + generalized `URLPolicy` is
/// Phase 3 work (T-P3-05..07). Until then this is the single
/// enforcement point for the one pane that exists.
///
/// The actual allow/deny decision lives in `decision(for:)` — a pure
/// function of the URL and the allowlist — so it can be unit-tested
/// without a live `WKWebView` navigation.
final class AllowlistNavigationDelegate: NSObject, WKNavigationDelegate, WKDownloadDelegate {
    /// Lowercased hosts this delegate permits. Stored lowercased so the
    /// comparison in `decision(for:)` is a plain set lookup.
    private let allowedHosts: Set<String>

    /// Whether downloads are permitted on this pane. Phase 1 is always
    /// `false` (deny everything); T-P3-08 makes it a per-adapter
    /// capability flag with a full `WKDownloadDelegate`.
    let allowsDownloads: Bool

    init(allowedHosts: [String], allowsDownloads: Bool = false) {
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
        self.allowsDownloads = allowsDownloads
        super.init()
    }

    /// Phase 1 default: the YouTube adapter's hosts. Phase 3 replaces
    /// this with the union registry (`AllowedDomains`).
    override convenience init() {
        self.init(allowedHosts: YouTubeAdapter().allowedHosts)
    }

    /// Decide whether a navigation to `url` is permitted.
    ///
    /// Denies unless the URL is `https`, has an extractable host, and
    /// that host (lowercased) is in the allowlist. HTTPS is enforced
    /// here rather than trusting the page — a redirect to `http://` or
    /// a `data:`/`file:` URL is cancelled. Host is pulled via
    /// `URLComponents` and lowercased so `Youtube.COM` cannot slip
    /// through unevaluated (brief §11.4).
    func decision(for url: URL?) -> WKNavigationActionPolicy {
        guard let url,
            url.scheme?.lowercased() == "https",
            let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host?.lowercased(),
            allowedHosts.contains(host)
        else {
            return .cancel
        }
        return .allow
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(decision(for: navigationAction.request.url))
    }

    // MARK: - Downloads (deny by default)

    /// A navigation that turns into a download (e.g. a click on a file
    /// link) routes here; take over as its delegate so we can refuse it.
    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    /// A response that turns into a download (e.g. `Content-Disposition:
    /// attachment`) routes here.
    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    /// Returning `nil` as the destination cancels the download. Phase 1
    /// denies every download regardless of adapter; T-P3-08 will honor
    /// `allowsDownloads` and pick a real destination when permitted.
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        completionHandler(nil)
    }
}
