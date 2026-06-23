//
//  LiveWebPaneDriver.swift
//  Singularity
//

import Foundation

/// Production `WebPaneDriving`: drives the real `WKWebView` through the
/// `WebPaneController`. Navigation actually loads and waits for
/// `didFinish`, so a `run_script` step runs only after the page is up.
@MainActor
final class LiveWebPaneDriver: WebPaneDriving {
    func navigate(_ controller: WebPaneController, to url: URL) async throws {
        try await controller.load(url)
    }

    func runHook(_ controller: WebPaneController, javaScript: String) async throws -> Any? {
        try await controller.evaluate(javaScript)
    }
}
