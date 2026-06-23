//
//  WebPaneDriving.swift
//  Singularity
//

import Foundation

/// The web-pane side effects the executor router performs: navigating a
/// pane and running an adapter's JavaScript hook in it.
///
/// Abstracted behind a protocol so the router's orchestration can be
/// unit-tested without a live `WKWebView` (a real navigation needs a
/// WindowServer and a content process). `LiveWebPaneDriver` is the
/// production implementation; tests substitute a recording fake.
@MainActor
protocol WebPaneDriving: AnyObject {
    /// Navigates the pane to `url` and returns once the load finishes.
    func navigate(_ controller: WebPaneController, to url: URL) async throws

    /// Runs `javaScript` (an adapter hook) in the pane's content world
    /// and returns whatever the script resolves to (e.g. a URL string).
    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any?
}
