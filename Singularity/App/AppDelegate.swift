//
//  AppDelegate.swift
//  Singularity
//

import AppKit
import Carbon.HIToolbox
import os

/// Owns lifecycle hooks SwiftUI does not expose directly: the activation
/// policy (T-P0-02) and the default global hotkey installation (T-P0-03).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyMonitor: HotkeyMonitor?
    private var hotkeyToken: HotkeyMonitor.Token?
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "lifecycle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: no Dock icon, no menu bar.
        // (T-P0-13 will set LSUIElement = YES to also kill the brief launch flash.)
        NSApp.setActivationPolicy(.accessory)

        // T-P0-03 manual verification hook: install the default ⌥Space hotkey
        // with a log callback. T-P0-04 introduces a Codable KeyCombo so the
        // combo can be rebound from Settings.
        let monitor = HotkeyMonitor()
        hotkeyToken = monitor.install(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey)
        ) { [logger] in
            logger.info("hotkey ⌥Space pressed")
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
