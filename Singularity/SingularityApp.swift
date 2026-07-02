//
//  SingularityApp.swift
//  Singularity
//

import SwiftUI

@main
struct SingularityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Share the delegate's stores so hotkey/appearance changes and
        // sign-in are the same objects the delegate reads.
        Settings {
            SettingsRootView(settings: appDelegate.settings, account: appDelegate.account)
        }
    }
}
