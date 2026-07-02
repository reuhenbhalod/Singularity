//
//  LoginItem.swift
//  Singularity
//

import Foundation
import ServiceManagement
import os

/// Thin wrapper over `SMAppService.mainApp` for the launch-at-login toggle
/// (US-SET-1). The registration persists across restarts; the OS may show a
/// Login Items approval prompt the first time.
enum LoginItem {
    private static let logger = Logger(
        subsystem: "com.reuhenbhalod.Singularity", category: "loginitem")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item. Returns whether
    /// the call succeeded; failures are logged, not thrown, so a Settings
    /// toggle never crashes.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            logger.error(
                "login item \(enabled ? "register" : "unregister") failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
