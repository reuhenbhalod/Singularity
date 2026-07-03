//
//  FirstRunController.swift
//  Singularity
//

import AppKit
import SwiftUI

/// Presents `FirstRunView` in a small standalone window at first launch
/// (T-P7-08). The app is an accessory (no Dock icon), so onboarding is a
/// plain titled window we bring to the front. Dismissing it marks the flow
/// complete and closes the window.
@MainActor
final class FirstRunController {
    private var window: NSWindow?
    private let permissions = PermissionsManager()

    /// Shows onboarding if it hasn't been completed. `account` is shared so
    /// a sign-in here persists everywhere.
    func showIfNeeded(flow: FirstRunFlow = FirstRunFlow(), account: AccountModel) {
        guard flow.shouldShow else { return }
        present(flow: flow, account: account)
    }

    /// Presents onboarding unconditionally — used by the Permissions tab's
    /// "re-run onboarding" link (US-SET-5).
    func present(flow: FirstRunFlow = FirstRunFlow(), account: AccountModel) {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let root = FirstRunView(permissions: permissions, account: account) { [weak self] in
            flow.markComplete()
            self?.close()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Welcome to Singularity"
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.orderOut(nil)
        window = nil
    }
}
