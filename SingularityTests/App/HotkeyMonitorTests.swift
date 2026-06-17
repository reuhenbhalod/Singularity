//
//  HotkeyMonitorTests.swift
//  SingularityTests
//

import AppKit
import Carbon.HIToolbox
import Testing

@testable import Singularity

@MainActor
struct HotkeyMonitorTests {
    /// T-P0-03 acceptance: install returns a non-nil token; uninstall runs
    /// without error. Uses ⌃⌥⌘F18 (an exotic combo unlikely to be bound)
    /// to avoid colliding with the default ⌥Space the AppDelegate test
    /// installs.
    @Test func installReturnsTokenAndUninstallSucceeds() async throws {
        let monitor = HotkeyMonitor()
        let token = monitor.install(
            keyCode: UInt32(kVK_F18),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            handler: {}
        )

        try #require(token != nil)

        if let token {
            monitor.uninstall(token)
        }
    }
}
