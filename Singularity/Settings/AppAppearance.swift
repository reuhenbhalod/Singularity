//
//  AppAppearance.swift
//  Singularity
//

import AppKit

/// Applies the persisted appearance preference to the whole app
/// (US-SET-1). "system" clears the override so the app follows macOS.
enum AppAppearance {
    @MainActor
    static func apply(_ id: String) {
        switch id {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil  // follow the system setting
        }
    }
}
