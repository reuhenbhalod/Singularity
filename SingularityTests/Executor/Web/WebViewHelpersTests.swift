//
//  WebViewHelpersTests.swift
//  SingularityTests
//
//  Uses XCTest (not Swift Testing): WebKit navigation callbacks and
//  content-process IPC are delivered on the main run loop, so a test
//  must suspend (not block) the main actor while waiting — these tests
//  are `async` and never call the blocking `wait(for:)`.
//
//  These are real integration tests that pass on an interactive macOS
//  session (where a WindowServer connection lets `WKWebView` actually
//  navigate). When run in a headless/automated harness with no usable
//  WindowServer, a navigation never commits; rather than fail or hang,
//  each test detects that and `XCTSkip`s. A single shared window is
//  reused across tests because creating a second NSWindow without a
//  WindowServer can crash the host.
//

import AppKit
import WebKit
import XCTest

@testable import Singularity

@MainActor
final class WebViewHelpersTests: XCTestCase {
    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        var onFinish: (() -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinish?()
        }
    }

    /// Single-resume guard so whichever of {didFinish, timeout} happens
    /// first wins without double-resuming the continuation.
    private final class Latch {
        var fired = false
    }

    // Shared so only one NSWindow/WKWebView is ever created (a second
    // window can crash a host with no WindowServer).
    private static var sharedWebView: WKWebView?
    private static var sharedWindow: NSWindow?
    private let loadDelegate = LoadDelegate()

    private func sharedWebView() -> WKWebView {
        if let existing = Self.sharedWebView { return existing }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.orderFrontRegardless()
        Self.sharedWebView = webView
        Self.sharedWindow = window
        return webView
    }

    /// Loads `html` and resolves to `true` once the navigation finishes,
    /// or `false` if it does not within `timeout` (no WindowServer).
    /// Suspends rather than blocks, so `didFinish` can be delivered.
    private func boundedLoad(
        _ webView: WKWebView,
        html: String,
        timeout: TimeInterval
    ) async -> Bool {
        let latch = Latch()
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            func finish(_ succeeded: Bool) {
                guard !latch.fired else { return }
                latch.fired = true
                cont.resume(returning: succeeded)
            }
            loadDelegate.onFinish = { finish(true) }
            webView.navigationDelegate = loadDelegate
            webView.loadHTMLString(html, baseURL: URL(string: "about:blank"))
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                finish(false)
            }
        }
    }

    /// Loads `html` into the shared web view, skipping the test if the
    /// environment cannot complete a WebKit navigation.
    private func loadedWebViewOrSkip(html: String) async throws -> WKWebView {
        let webView = sharedWebView()
        let loaded = await boundedLoad(webView, html: html, timeout: 8)
        try XCTSkipUnless(
            loaded,
            "WKWebView navigation did not complete — no usable WindowServer. "
                + "These assertions run on an interactive macOS session."
        )
        return webView
    }

    /// T-P1-06 acceptance: a selector that appears after a 200ms timer
    /// resolves the wait.
    func testResolvesWhenSelectorAppearsLater() async throws {
        let html = """
            <html><body>
            <script>
            setTimeout(() => {
                const el = document.createElement('div');
                el.id = 'delayed';
                document.body.appendChild(el);
            }, 200);
            </script>
            </body></html>
            """
        let webView = try await loadedWebViewOrSkip(html: html)
        // Should not throw: the element shows up well within 5s.
        try await webView.waitForSelector("#delayed", timeout: 5)
    }

    /// An element already present resolves immediately.
    func testResolvesImmediatelyWhenSelectorAlreadyPresent() async throws {
        let webView = try await loadedWebViewOrSkip(
            html: "<html><body><div id='here'></div></body></html>"
        )
        try await webView.waitForSelector("#here", timeout: 5)
    }

    /// T-P1-06 acceptance: a selector that never appears throws once
    /// the 1s timeout elapses.
    func testThrowsWhenSelectorNeverAppears() async throws {
        let webView = try await loadedWebViewOrSkip(html: "<html><body></body></html>")
        do {
            try await webView.waitForSelector("#never", timeout: 1)
            XCTFail("expected waitForSelector to throw on timeout")
        } catch is WebViewHelperError {
            // expected: timed out
        }
    }
}
