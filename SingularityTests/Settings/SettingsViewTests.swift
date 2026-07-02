//
//  SettingsViewTests.swift
//  SingularityTests
//

import SwiftUI
import Testing

@testable import Singularity

@MainActor
struct SettingsViewTests {
    private func store() throws -> SettingsStore {
        SettingsStore(defaults: try #require(UserDefaults(suiteName: "t-\(UUID().uuidString)")))
    }

    /// T-P7-10: the tabbed Settings root instantiates and hosts.
    @Test func settingsRootHosts() throws {
        let view = SettingsRootView(
            settings: try store(),
            account: AccountModel(store: InMemoryIdentityStore()))
        #expect(NSHostingView(rootView: view).rootView is SettingsRootView)
    }

    /// T-P7-11: the General tab hosts.
    @Test func generalTabHosts() throws {
        let view = GeneralTabView(settings: try store())
        #expect(NSHostingView(rootView: view).rootView is GeneralTabView)
    }

    /// T-P7-12: the Planner tab hosts.
    @Test func plannerTabHosts() throws {
        let view = PlannerTabView(settings: try store())
        #expect(NSHostingView(rootView: view).rootView is PlannerTabView)
    }

    /// T-P7-20/22: the Advanced tab hosts.
    @Test func advancedTabHosts() throws {
        let view = AdvancedTabView(
            settings: try store(),
            account: AccountModel(store: InMemoryIdentityStore()))
        #expect(NSHostingView(rootView: view).rootView is AdvancedTabView)
    }

    /// T-P7-18: the Permissions tab hosts.
    @Test func permissionsTabHosts() {
        let view = PermissionsTabView(
            permissions: PermissionsManager(isTrusted: { false }, fdaProbe: { .denied }))
        #expect(NSHostingView(rootView: view).rootView is PermissionsTabView)
    }

    /// T-P7-17: the Routines tab hosts.
    @Test func routinesTabHosts() {
        let view = RoutinesTabView(
            store: RoutineStore(
                url: FileManager.default.temporaryDirectory
                    .appendingPathComponent("rt-\(UUID().uuidString).json")))
        #expect(NSHostingView(rootView: view).rootView is RoutinesTabView)
    }

    /// The Account tab hosts in both signed-out and signed-in states.
    @Test func accountTabHostsBothStates() {
        let signedOut = AccountTabView(account: AccountModel(store: InMemoryIdentityStore()))
        #expect(NSHostingView(rootView: signedOut).rootView is AccountTabView)

        let signedIn = AccountTabView(
            account: AccountModel(
                store: InMemoryIdentityStore(
                    IdentityRecord(user: "u", displayName: "Abhiram P", email: "a@b.com"))))
        #expect(NSHostingView(rootView: signedIn).rootView is AccountTabView)
    }
}
