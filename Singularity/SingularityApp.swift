//
//  SingularityApp.swift
//  Singularity
//

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
