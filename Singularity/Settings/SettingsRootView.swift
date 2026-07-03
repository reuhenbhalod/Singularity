//
//  SettingsRootView.swift
//  Singularity
//

import SwiftUI

/// The Settings root (US-SET-1..7): a sidebar of sections on the left, the
/// selected section's content on the right. A sidebar (not a TabView) so
/// all seven options are visible at once — no top segmented control with an
/// overflow arrow.
struct SettingsRootView: View {
    @Bindable var settings: SettingsStore
    @Bindable var account: AccountModel
    @State private var permissions = PermissionsManager()
    @State private var selection: Section? = .general

    enum Section: String, CaseIterable, Identifiable {
        case general, planner, safety, routines, permissions, account, advanced
        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .planner: return "Planner"
            case .safety: return "Safety"
            case .routines: return "Routines"
            case .permissions: return "Permissions"
            case .account: return "Account"
            case .advanced: return "Advanced"
            }
        }

        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .planner: return "cpu"
            case .safety: return "lock.shield"
            case .routines: return "list.bullet.rectangle"
            case .permissions: return "hand.raised"
            case .account: return "person.crop.circle"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.symbol).tag(section)
                }
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(selection?.title ?? "Settings")
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 720, height: 480)
    }

    @ViewBuilder private var detail: some View {
        switch selection ?? .general {
        case .general: GeneralTabView(settings: settings)
        case .planner: PlannerTabView(settings: settings)
        case .safety: SafetyTabView(settings: settings)
        case .routines: RoutinesTabView()
        case .permissions: PermissionsTabView(permissions: permissions)
        case .account: AccountTabView(account: account)
        case .advanced: AdvancedTabView(settings: settings, account: account)
        }
    }
}
