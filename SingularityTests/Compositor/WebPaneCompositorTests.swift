//
//  WebPaneCompositorTests.swift
//  SingularityTests
//

import SwiftUI
import Testing
import WebKit

@testable import Singularity

@MainActor
struct WebPaneCompositorTests {
    /// T-P1-08 acceptance: a `.web` pane is added and the compositor
    /// renders it without crashing.
    @Test func addingWebPaneTilesIt() {
        let store = CompositorStore()
        let controller = WebPaneController(adapter: YouTubeAdapter())
        store.add(Pane(title: "youtube", kind: .web(controller)))

        #expect(store.panes.count == 1)

        let hosting = NSHostingView(rootView: CompositorView(store: store))
        #expect(hosting.rootView is CompositorView)
    }

    /// T-P1-08 acceptance: closing the pane releases the controller and
    /// its `WKWebView` (no lingering strong references).
    @Test func closingWebPaneReleasesWebView() {
        let store = CompositorStore()
        weak var weakController: WebPaneController?
        weak var weakWebView: WKWebView?
        let paneID = UUID()

        autoreleasepool {
            let controller = WebPaneController(adapter: YouTubeAdapter())
            weakController = controller
            weakWebView = controller.webView
            store.add(Pane(title: "youtube", kind: .web(controller), id: paneID))
            store.remove(id: paneID)
        }

        #expect(weakController == nil)
        #expect(weakWebView == nil)
    }

    /// T-P1-08 acceptance: dismissing the shell (which clears the
    /// compositor, per T-P0-11) disposes the web pane.
    @Test func dismissDisposesWebPane() {
        let store = CompositorStore()
        weak var weakController: WebPaneController?

        autoreleasepool {
            let controller = WebPaneController(adapter: YouTubeAdapter())
            weakController = controller
            store.add(Pane(title: "youtube", kind: .web(controller)))
            store.clear()
        }

        #expect(weakController == nil)
    }
}
