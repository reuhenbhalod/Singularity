//
//  PermissionsTabView.swift
//  Singularity
//

import SwiftUI

/// Shows the three TCC permissions with live status and a one-click jump to
/// the right System Settings pane (US-SET-5 / US-PERM-1). Polls only while
/// this tab is on screen (T-P7-06).
struct PermissionsTabView: View {
    @Bindable var permissions: PermissionsManager

    var body: some View {
        Form {
            Section {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionRow(kind: kind, status: permissions.status(of: kind))
                }
            } header: {
                Text("System permissions")
            } footer: {
                Text(
                    "Singularity never changes these for you — grant them yourself in System "
                        + "Settings. A denied permission only disables the lane that needs it; the "
                        + "shell keeps working.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { permissions.startPolling() }
        .onDisappear { permissions.stopPolling() }
    }
}

private struct PermissionRow: View {
    let kind: PermissionKind
    let status: PermissionsManager.Status

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.body)
                Text(kind.why).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(status: status)
            Button("Open Settings") { SystemSettingsLinks.open(kind) }
                .buttonStyle(.link)
        }
        .padding(.vertical, 2)
    }
}

private struct StatusBadge: View {
    let status: PermissionsManager.Status

    var body: some View {
        let (text, color, symbol): (String, Color, String) = {
            switch status {
            case .granted: return ("Granted", .green, "checkmark.circle.fill")
            case .denied: return ("Denied", .red, "xmark.circle.fill")
            case .unknown: return ("Not checked", .secondary, "questionmark.circle")
            }
        }()
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }
}
