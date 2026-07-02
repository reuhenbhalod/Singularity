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

    var body: some View {
        TabView {
            GeneralTabView()
                .tabItem { Label("General", systemImage: "gearshape") }
            PlannerTabView(settings: settings)
                .tabItem { Label("Planner", systemImage: "cpu") }
            SafetyTabView(settings: settings)
                .tabItem { Label("Safety", systemImage: "lock.shield") }
            AccountTabView(account: account)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .frame(width: 480, height: 460)
    }
}
