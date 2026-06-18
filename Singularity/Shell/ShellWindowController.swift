//
//  ShellWindowController.swift
//  Singularity
//

import AppKit
import os

/// Owns the `ShellPanel` lifecycle: show/hide on hotkey, screen-of-
/// cursor sizing for multi-monitor, presentation-option swapping
/// (hides menu bar + Dock while visible), and focus return to the
/// prior app on dismiss.
///
/// Per research brief §2: panel sizes to the screen containing the
/// cursor at summon time, not always the primary display. Per
/// architect T-P0-06 notes: `presentationOptions` are swapped on
/// show / restored on hide; on hide we call `NSApp.hide(nil)` so the
/// system returns focus to the previously frontmost app (the
/// Raycast / Alfred pattern).
///
/// Ordering matters in `show()`: `presentationOptions` are only
/// honored while the app is the *active* application, so the
/// activation call must come first. Using
/// `activate(ignoringOtherApps:)` (deprecated since macOS 14 but
/// still works) because the new polite `activate()` can refuse to
/// steal focus from a foreground app — which is exactly what a
/// hotkey-summoned shell needs to do.
@MainActor
final class ShellWindowController {
    private var panel: ShellPanel?
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private(set) var isShowing = false
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "shell")

    func toggle() {
        if isShowing {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard !isShowing else { return }

        let screen = currentCursorScreen()
        let panel = ShellPanel(contentRect: screen.frame)
        panel.setFrame(screen.frame, display: true)
        // T-P0-07 sets the panel's contentView to ShellRootView.
        // Until then, the panel is given a temporary translucent tint
        // so it is visible during manual verification of T-P0-06.
        panel.backgroundColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.35)
        self.panel = panel

        // Activate first so presentationOptions take effect; Apple's
        // docs say those options are only honored for the active app.
        NSApp.activate(ignoringOtherApps: true)
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideMenuBar, .hideDock]
        panel.makeKeyAndOrderFront(nil)

        isShowing = true
        logger.info("show: panel on screen \(screen.frame.debugDescription, privacy: .public)")
    }

    func hide() {
        guard isShowing, let panel else { return }

        panel.orderOut(nil)
        self.panel = nil

        NSApp.presentationOptions = savedPresentationOptions

        // Returns focus to whatever app was frontmost before we summoned.
        // Without this, focus stays "in nowhere" because our accessory
        // app has no Dock icon / standard window to fall back to.
        NSApp.hide(nil)

        isShowing = false
        logger.info("hide: panel ordered out")
    }

    /// Returns the `NSScreen` whose frame contains the mouse cursor,
    /// or the main screen as a fallback.
    private func currentCursorScreen() -> NSScreen {
        let location = NSEvent.mouseLocation
        for screen in NSScreen.screens where screen.frame.contains(location) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
