//
//  PermissionBanner.swift
//  Singularity
//

import SwiftUI

/// A slim, non-blocking strip at the top of the shell that appears when a
/// TCC permission is revoked mid-session (T-P7-09). It never steals focus
/// or blocks input — it just names what's missing and offers the fix, so a
/// lane that's about to fail explains itself before it does.
struct PermissionBanner: View {
    let denied: [PermissionKind]

    var body: some View {
        if !denied.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white)
                Spacer()
                if let first = denied.first {
                    Button("Open Settings") { SystemSettingsLinks.open(first) }
                        .buttonStyle(.link)
                        .tint(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.18))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.yellow.opacity(0.35)).frame(height: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var message: String {
        let names: [String] = denied.map { $0.title }
        let list: String
        if names.count == 1 {
            list = names[0]
        } else if names.count == 2 {
            list = names[0] + " and " + names[1]
        } else {
            list = names.dropLast().joined(separator: ", ") + ", and " + (names.last ?? "")
        }
        let single = denied.count == 1
        let verb = single ? "is" : "are"
        let pronoun = single ? "it" : "them"
        return "\(list) \(verb) off — commands needing \(pronoun) won't run until you re-enable \(pronoun)."
    }
}
