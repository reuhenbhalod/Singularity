//
//  FirstRunView.swift
//  Singularity
//

import AuthenticationServices
import SwiftUI

/// One-time onboarding (T-P7-08): what the app is, the permission checklist,
/// an optional Sign in with Apple, and a "Skip for now". The shell is fully
/// usable without granting anything — missing permissions just disable the
/// lane that needs them, surfaced later by the in-shell banner.
struct FirstRunView: View {
    @Bindable var permissions: PermissionsManager
    @Bindable var account: AccountModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Singularity").font(.largeTitle.bold())
                Text("A fullscreen command shell. Press your hotkey, type what you want in plain English, and it acts.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Permissions").font(.headline)
                Text("Grant these when you're ready — you can skip and do it later in Settings. Each only unlocks the lane that needs it.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(PermissionKind.allCases) { kind in
                    checklistRow(kind)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sign in (optional)").font(.headline)
                if account.isSignedIn {
                    Label("Signed in", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        account.signIn(from: result)
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 38)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Skip for now") { onDone() }
                Button("Get Started") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460, height: 520)
        .onAppear { permissions.startPolling() }
        .onDisappear { permissions.stopPolling() }
    }

    private func checklistRow(_ kind: PermissionKind) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: symbol(for: permissions.status(of: kind)))
                .foregroundStyle(color(for: permissions.status(of: kind)))
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                Text(kind.why).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open") { SystemSettingsLinks.open(kind) }
                .buttonStyle(.link)
        }
    }

    private func symbol(for status: PermissionsManager.Status) -> String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "circle"
        case .unknown: return "circle.dashed"
        }
    }

    private func color(for status: PermissionsManager.Status) -> Color {
        status == .granted ? .green : .secondary
    }
}
