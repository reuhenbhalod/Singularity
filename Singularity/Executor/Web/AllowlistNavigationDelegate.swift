//
//  AllowlistNavigationDelegate.swift
//  Singularity
//

import Foundation
import WebKit

/// `WKNavigationDelegate` that refuses to let a web pane navigate
/// anywhere `URLPolicy` denies (research brief §11.4) — HTTPS-only, no
/// userinfo, host on the central `AllowedDomains` allowlist. Denials are
/// logged via `SafetyLog`.
///
/// The decision lives in `decision(for:)` — a pure function of the URL
/// and the policy — so it can be unit-tested without a live navigation.
final class AllowlistNavigationDelegate: NSObject, WKNavigationDelegate, WKDownloadDelegate {
    private let policy: URLPolicy

    /// Whether downloads are permitted on this pane. Defaults to `false`
    /// (deny everything); T-P3-08 makes it a per-adapter capability.
    let allowsDownloads: Bool

    /// Called when a navigation finishes. `WebPaneController.load(_:)`
    /// uses this to bridge `didFinish` into an `async` continuation.
    var onDidFinish: (() -> Void)?

    /// Called when a navigation fails (provisional or committed).
    var onDidFail: ((any Error) -> Void)?

    init(policy: URLPolicy = URLPolicy(), allowsDownloads: Bool = false) {
        self.policy = policy
        self.allowsDownloads = allowsDownloads
        super.init()
    }

    /// Decide whether a navigation to `url` is permitted by consulting
    /// `URLPolicy`. A denied or missing URL is cancelled and logged.
    func decision(for url: URL?) -> WKNavigationActionPolicy {
        guard let url else { return .cancel }
        switch policy.evaluate(url: url) {
        case .allow:
            return .allow
        case .deny:
            SafetyLog.urlDenied(host: url.host ?? "(none)", url: url)
            return .cancel
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(decision(for: navigationAction.request.url))
    }

    // MARK: - Load completion

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDidFinish?()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        onDidFail?(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        onDidFail?(error)
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

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        completionHandler(downloadDestination(suggestedFilename: suggestedFilename))
    }

    /// Destination for a download, or `nil` to cancel it. Denies (and
    /// logs) unless `allowsDownloads`; when permitted, targets the
    /// user's Downloads folder. Pure, so it's unit-testable without a
    /// real `WKDownload`.
    func downloadDestination(suggestedFilename: String) -> URL? {
        guard allowsDownloads else {
            SafetyLog.downloadDenied(filename: suggestedFilename)
            return nil
        }
        return FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(suggestedFilename)
    }
}
