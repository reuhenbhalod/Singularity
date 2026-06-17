//
//  ShellPanel.swift
//  Singularity
//

import AppKit

/// Kiosk-overlay panel for the Singularity shell.
///
/// Configured per research brief §2 (Raycast / Alfred recipe):
/// - Level above the menu bar so the panel floats over everything,
///   including macOS-fullscreen apps.
/// - Collection behavior joins all Spaces and remains visible over
///   fullscreen Spaces without taking one of its own.
/// - `.nonactivatingPanel` style means showing the panel does not
///   move our accessory app to the foreground (no Space switch, no
///   focus theft of the user's prior app context).
/// - Borderless + transparent so the SwiftUI content owns the whole
///   visual surface; the panel is just a container.
@MainActor
final class ShellPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Chromeless, immovable kiosk overlay.
        isMovable = false
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear

        // Keep the panel visible when the user clicks another app;
        // T-P0-06 will manage explicit show/hide via the controller.
        hidesOnDeactivate = false

        // Show/hide is driven by our own controller; suppress AppKit's
        // built-in fade so toggling is instant.
        animationBehavior = .none
    }

    /// Borderless + .nonactivatingPanel NSPanels default to `false`
    /// here; we need keyboard focus for the command input.
    override var canBecomeKey: Bool { true }

    /// Accessory apps should not have a "main" window in the
    /// AppKit sense; the panel takes key focus while showing but
    /// never becomes main.
    override var canBecomeMain: Bool { false }
}
