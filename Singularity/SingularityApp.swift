//
//  SingularityApp.swift
//  Singularity
//

import AppKit
import SwiftUI

@main
struct SingularityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Phase 7 (US-SET-1..7) fills these tabs.
        Settings {
            EmptyView()
        }
    }
}

// Inlined here until a later task introduces a file-add workflow.
// Owns NSApp activation policy and any other AppKit lifecycle hooks
// SwiftUI does not expose directly.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: no Dock icon, no menu bar. The shell is summoned via the
        // global hotkey added in T-P0-03; there is no Dock icon to click.
        NSApp.setActivationPolicy(.accessory)
    }
}
