//
//  SettingsRootView.swift
//  Singularity
//

import SwiftUI

/// The Settings scene's root: a tabbed window (US-SET-1..7). Phase 5's
/// SafetyTabView finally gets a home here, alongside the Account page.
/// (General, Planner, Safety, Account today; Routines / Permissions /
/// Advanced land as their features do.)
struct SettingsRootView: View {
    @Bindable var settings: SettingsStore
    @Bindable var account: AccountModel
    @State private var permissions = PermissionsManager()

    var body: some View {
        TabView {
            GeneralTabView(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            PlannerTabView(settings: settings)
                .tabItem { Label("Planner", systemImage: "cpu") }
            SafetyTabView(settings: settings)
                .tabItem { Label("Safety", systemImage: "lock.shield") }
            RoutinesTabView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }
            PermissionsTabView(permissions: permissions)
                .tabItem { Label("Permissions", systemImage: "hand.raised") }
            AccountTabView(account: account)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
            AdvancedTabView(settings: settings, account: account)
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 480, height: 460)
    }
}
