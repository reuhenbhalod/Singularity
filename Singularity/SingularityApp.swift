//
//  SingularityApp.swift
//  Singularity
//

import SwiftUI

@main
struct SingularityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var account = AccountModel()

    var body: some Scene {
        // Share the delegate's SettingsStore so hotkey/appearance changes
        // in Settings are the same object the delegate re-reads live.
        Settings {
            SettingsRootView(settings: appDelegate.settings, account: account)
        }
    }
}
