//
//  ConfirmGateView.swift
//  Singularity
//

import SwiftUI

/// Modal-inline preview shown over the shell when a mutating action needs
/// confirmation (US-SAFE-5). Renders nothing until `gate.pending` is set;
/// Confirm/Cancel (or Esc) resolve it. Explicit confirm is always
/// required — it never auto-proceeds, even after Touch ID.
struct ConfirmGateView: View {
    @Bindable var gate: ShellConfirmGate

    var body: some View {
        if let preview = gate.pending {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text(preview.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(ShellStyle.textPrimary)
                    Text(preview.detail)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(ShellStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Spacer()
                        Button("Cancel") { gate.resolve(false) }
                            .keyboardShortcut(.cancelAction)
                        Button("Confirm") { gate.resolve(true) }
                            .keyboardShortcut(.defaultAction)
                            .tint(ShellStyle.accent)
                    }
                }
                .padding(22)
                .frame(maxWidth: 460)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).strokeBorder(ShellStyle.hairline, lineWidth: 1)
                )
                .padding(40)
            }
            .transition(.opacity)
        }
    }
}
