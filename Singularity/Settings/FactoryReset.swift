//
//  FactoryReset.swift
//  Singularity
//

import Foundation

/// Wipes all local state the app has written: settings, saved routines,
/// and the stored Apple ID identity (T-P7-22). Everything Singularity
/// keeps is local, so this returns the app to a freshly installed state.
/// There is nothing in the cloud to also clear.
@MainActor
enum FactoryReset {
    static func run(
        settings: SettingsStore,
        identityStore: any IdentityStore = KeychainIdentityStore(),
        routinesURL: URL = RoutineStore.defaultURL()
    ) {
        settings.resetToDefaults()
        identityStore.clear()
        // Routines file — absent is fine (removeItem throws, ignored).
        try? FileManager.default.removeItem(at: routinesURL)
    }
}
