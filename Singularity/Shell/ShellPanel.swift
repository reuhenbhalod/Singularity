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

        // CGShieldingWindowLevel (used for screen-saver / lock screen) is
        // above the system menu bar's render level (25). mainMenu + 1 (also
        // 25) collides with the menu bar's own level, so the menu bar wins
        // visually on macOS 14+. Both values are accepted by the T-P0-05
        // acceptance test per the architect's plan.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
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
