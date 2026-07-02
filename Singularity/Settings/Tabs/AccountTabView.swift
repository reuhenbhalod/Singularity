//
//  AccountTabView.swift
//  Singularity
//

import AppKit
import AuthenticationServices
import SwiftUI

/// The Account tab (US-ACC-1): identity (or Sign in with Apple), an About
/// section, and sign-out. No subscriptions or upsells — Singularity is
/// free and stores nothing beyond this identity record.
struct AccountTabView: View {
    @Bindable var account: AccountModel
    @State private var confirmingSignOut = false

    var body: some View {
        Form {
            Section("Identity") {
                if let identity = account.identity {
                    signedInRow(identity)
                } else {
                    Text("Not signed in").foregroundStyle(.secondary)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 38)
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Button("Privacy Policy") { openPrivacyPolicy() }
                Text(
                    "Singularity keeps no memory or history. The session log clears when you "
                        + "dismiss the shell, intent parsing runs on your local Ollama, and "
                        + "nothing is stored or synced to a server."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if account.isSignedIn {
                Section {
                    Button("Sign Out", role: .destructive) { confirmingSignOut = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Sign out of Singularity? You'll need to sign back in next time you open the shell.",
            isPresented: $confirmingSignOut
        ) {
            Button("Sign Out", role: .destructive) { account.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func signedInRow(_ identity: IdentityRecord) -> some View {
        HStack(spacing: 14) {
            avatar(for: identity)
            VStack(alignment: .leading, spacing: 3) {
                Text(identity.displayName ?? "Signed in with Apple ID")
                    .font(.headline)
                if let email = identity.email {
                    Text(identity.emailIsRelayed ? "\(email) (relayed)" : email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func avatar(for identity: IdentityRecord) -> some View {
        let initials =
            (identity.displayName ?? "")
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
        return ZStack {
            Circle().fill(ShellStyle.accent.opacity(0.3)).frame(width: 46, height: 46)
            if initials.isEmpty {
                Image(systemName: "person.fill").foregroundStyle(ShellStyle.accent)
            } else {
                Text(initials).font(.headline).foregroundStyle(ShellStyle.accent)
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func handleSignIn(_ result: Result<ASAuthorization, any Error>) {
        guard case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            return  // failure (e.g. Sign in with Apple capability not set up) — button stays
        }
        let name =
            [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        account.signIn(
            IdentityRecord(
                user: credential.user,
                displayName: name.isEmpty ? nil : name,
                email: credential.email))
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://github.com/reuhenbhalod/Singularity") {
            NSWorkspace.shared.open(url)
        }
    }
}
