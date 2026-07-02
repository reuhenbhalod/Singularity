//
//  SingularityApp.swift
//  Singularity
//

import SwiftUI

@main
struct SingularityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = SettingsStore()
    @State private var account = AccountModel()

    var body: some Scene {
        Settings {
            SettingsRootView(settings: settings, account: account)
        }
    }
}
