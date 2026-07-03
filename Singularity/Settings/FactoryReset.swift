//
//  FactoryReset.swift
//  Singularity
//

import Foundation
import WebKit

/// Wipes all local state the app has written, matching the four factory-
/// reset targets in the spec (US-SET-7): SettingsStore/UserDefaults, the
/// Keychain identity, the routines store, and every per-adapter persistent
/// WKWebsiteDataStore (logged-in web sessions). Everything Singularity
/// keeps is local, so this returns the app to a freshly installed state.
@MainActor
enum FactoryReset {
    static func run(
        settings: SettingsStore,
        identityStore: any IdentityStore = KeychainIdentityStore(),
        routinesURL: URL = RoutineStore.defaultURL(),
        firstRun: FirstRunFlow = FirstRunFlow(),
        clearWebData: Bool = true
    ) async {
        settings.resetToDefaults()
        identityStore.clear()
        // Routines file — absent is fine (removeItem throws, ignored).
        try? FileManager.default.removeItem(at: routinesURL)
        // Re-present onboarding on next launch, like a fresh install.
        firstRun.reset()
        if clearWebData {
            await Self.clearWebData()
        }
    }

    /// Removes every persistent WKWebsiteDataStore the app created (one per
    /// web adapter), so logged-in web sessions don't survive a reset.
    private static func clearWebData() async {
        let identifiers: [UUID] = await withCheckedContinuation { continuation in
            WKWebsiteDataStore.fetchAllDataStoreIdentifiers { continuation.resume(returning: $0) }
        }
        for identifier in identifiers {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                WKWebsiteDataStore.remove(forIdentifier: identifier) { _ in continuation.resume() }
            }
        }
    }
}
