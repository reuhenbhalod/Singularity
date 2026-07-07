//
//  WebPaneView.swift
//  Singularity
//

import SwiftUI
import WebKit

/// Hosts a `WebPaneController`'s `WKWebView` inside the compositor, with a
/// slim navigation bar (back / forward / reload / open-in-Safari) above it.
/// The web view is owned by the controller (which lives in the `Pane`), so
/// this view never creates or retains its own.
struct WebPaneView: View {
    let controller: WebPaneController

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
            WebViewHost(webView: controller.webView)
        }
    }

    private var navBar: some View {
        HStack(spacing: 6) {
            Button(action: controller.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!controller.canGoBack)
            .help("Back")

            Button(action: controller.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!controller.canGoForward)
            .help("Forward")

            Button(action: controller.reload) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload")

            Spacer()

            Button(action: controller.openInDefaultBrowser) {
                Image(systemName: "safari")
            }
            .help("Open in Safari — use this to sign in when a site blocks the embedded browser")
        }
        .buttonStyle(.borderless)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

/// The `NSViewRepresentable` that surfaces the controller's web view.
private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
