//
//  SettingsWindowController.swift
//  Singularity
//

import AppKit
import SwiftUI

/// Presents the Settings window as a centered, titled overlay **on top of
/// the shell** — the shell stays up behind it. It attaches as a child of
/// the shell panel so it floats above that panel's very high window level
/// and travels/hides with it. A single window is reused across opens.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let account: AccountModel
    private var window: NSWindow?

    init(settings: SettingsStore, account: AccountModel) {
        self.settings = settings
        self.account = account
    }

    /// Shows Settings centered over `parent` (the shell panel), above it,
    /// without dismissing the shell.
    func present(childOf parent: NSWindow?) {
        let window = self.window ?? makeWindow()
        self.window = window

        if let parent, window.parent !== parent {
            window.parent?.removeChildWindow(window)
            parent.addChildWindow(window, ordered: .above)
        }
        center(window, on: parent)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingView(
            rootView: SettingsRootView(settings: settings, account: account))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Settings"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        return window
    }

    private func center(_ window: NSWindow, on parent: NSWindow?) {
        let screenFrame = (parent?.screen ?? NSScreen.main)?.frame ?? window.frame
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2))
    }
}
