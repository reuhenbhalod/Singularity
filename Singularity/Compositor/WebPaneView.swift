//
//  WebPaneView.swift
//  Singularity
//

import SwiftUI
import WebKit

/// Hosts a `WebPaneController`'s `WKWebView` inside the SwiftUI
/// compositor. The web view is owned by the controller (which lives in
/// the `Pane`), so this representable just surfaces it — it never
/// creates or retains its own.
struct WebPaneView: NSViewRepresentable {
    let controller: WebPaneController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // The controller drives navigation; nothing to push from here.
    }
}
