//
//  AppDelegate.swift
//  Singularity
//

import AppKit
import Carbon.HIToolbox
import os

/// Owns lifecycle hooks SwiftUI does not expose directly: the activation
/// policy (T-P0-02), the global hotkey installation (T-P0-03), applying the
/// persisted appearance, and the shell window controller it toggles
/// (T-P0-06). The hotkey re-registers live when the Settings preset changes
/// (T-P7-11) — it listens for `.summonHotkeyChanged`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyMonitor: HotkeyMonitor?
    private var hotkeyToken: HotkeyMonitor.Token?
    /// Shared with the SwiftUI Settings scene so a hotkey/appearance change
    /// there is the same object this delegate reads when re-registering.
    let settings = SettingsStore()
    let shellController = ShellWindowController()
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "lifecycle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: no Dock icon, no menu bar.
        NSApp.setActivationPolicy(.accessory)

        // Apply the saved appearance before any window shows.
        AppAppearance.apply(settings.appearanceID)

        let monitor = HotkeyMonitor()
        hotkeyMonitor = monitor
        installHotkey()

        // Re-register when the user picks a different summon combo — the
        // General tab posts this after persisting the new preset.
        NotificationCenter.default.addObserver(
            forName: .summonHotkeyChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.installHotkey() }
        }
    }

    /// (Re)installs the global hotkey from the current settings preset,
    /// uninstalling any previous registration first.
    private func installHotkey() {
        if let token = hotkeyToken {
            hotkeyMonitor?.uninstall(token)
            hotkeyToken = nil
        }
        let combo = HotkeyPreset.preset(id: settings.summonHotkeyID).combo
        hotkeyToken = hotkeyMonitor?.install(
            keyCode: combo.keyCode,
            modifiers: combo.carbonModifierMask
        ) { [shellController, logger] in
            logger.info("summon hotkey pressed — toggling shell")
            shellController.toggle()
        }
        if hotkeyToken == nil {
            logger.error("Failed to install summon hotkey — another app may own that combo")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let token = hotkeyToken {
            hotkeyMonitor?.uninstall(token)
        }
    }
}
