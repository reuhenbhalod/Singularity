//
//  AppDelegate.swift
//  Singularity
//

import AppKit
import Carbon.HIToolbox
import os

/// Owns lifecycle hooks SwiftUI does not expose directly: the activation
/// policy (T-P0-02), the default global hotkey installation (T-P0-03),
/// and the shell window controller it toggles (T-P0-06).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyMonitor: HotkeyMonitor?
    private var hotkeyToken: HotkeyMonitor.Token?
    let shellController = ShellWindowController()
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "lifecycle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: no Dock icon, no menu bar.
        // (T-P0-13 will set LSUIElement = YES to also kill the brief launch flash.)
        NSApp.setActivationPolicy(.accessory)

        // T-P0-04 introduces KeyCombo; this still hardcodes the literals so
        // tests that touch AppDelegate do not need a Settings store. The
        // hardcode and KeyCombo.defaultShellSummon are kept in sync.
        let combo = KeyCombo.defaultShellSummon
        let monitor = HotkeyMonitor()
        hotkeyToken = monitor.install(
            keyCode: combo.keyCode,
            modifiers: combo.carbonModifierMask
        ) { [shellController, logger] in
            logger.info("hotkey ⌥Space pressed — toggling shell")
            shellController.toggle()
        }
        hotkeyMonitor = monitor

        if hotkeyToken == nil {
            logger.error("Failed to install ⌥Space hotkey — another app may own it")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let token = hotkeyToken {
            hotkeyMonitor?.uninstall(token)
        }
    }
}
