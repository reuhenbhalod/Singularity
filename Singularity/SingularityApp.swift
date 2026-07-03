//
//  SingularityApp.swift
//  Singularity
//

import SwiftUI

@main
struct SingularityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The shell presents Settings itself (a centered overlay above the
        // shell, via SettingsWindowController), so this scene is an empty
        // placeholder — SwiftUI's App still requires one Scene.
        Settings { EmptyView() }
    }
}
