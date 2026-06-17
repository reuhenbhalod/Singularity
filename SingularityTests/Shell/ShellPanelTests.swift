//
//  ShellPanelTests.swift
//  SingularityTests
//

import AppKit
import Testing

@testable import Singularity

@MainActor
struct ShellPanelTests {
    private static let rect = NSRect(x: 0, y: 0, width: 800, height: 600)

    /// T-P0-05 acceptance: window level sits above the menu bar
    /// (either mainMenu+1 — the chosen value — or
    /// CGShieldingWindowLevel, per architect's plan).
    @Test func levelIsAboveMenuBar() {
        let panel = ShellPanel(contentRect: Self.rect)
        let mainMenuPlusOne = NSWindow.Level(
            rawValue: NSWindow.Level.mainMenu.rawValue + 1
        )
        let shielding = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        #expect(panel.level == mainMenuPlusOne || panel.level == shielding)
    }

    /// T-P0-05 acceptance: collection behavior includes the
    /// kiosk-overlay triple.
    @Test func collectionBehaviorIsKioskOverlay() {
        let panel = ShellPanel(contentRect: Self.rect)
        let required: NSWindow.CollectionBehavior =
            [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        #expect(panel.collectionBehavior.contains(required))
    }

    /// T-P0-05 acceptance: style mask includes `.nonactivatingPanel`.
    @Test func styleMaskContainsNonactivating() {
        let panel = ShellPanel(contentRect: Self.rect)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }

    @Test func canBecomeKeyForKeyboardInput() {
        let panel = ShellPanel(contentRect: Self.rect)
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
    }

    @Test func panelIsChromelessAndImmovable() {
        let panel = ShellPanel(contentRect: Self.rect)
        #expect(!panel.isMovable)
        #expect(!panel.isOpaque)
        #expect(!panel.hasShadow)
        #expect(panel.styleMask.contains(.borderless))
    }
}
