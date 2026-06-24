//
//  CommandInputView.swift
//  Singularity
//

import SwiftUI

/// Presentation-only view for the command input. Binds to a
/// `CommandInputViewModel` for state and behavior. Auto-focuses on
/// appear; routes Return / Escape through the view model.
struct CommandInputView: View {
    @Bindable var viewModel: CommandInputViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isFocused ? ShellStyle.accent : ShellStyle.textTertiary)
                .animation(.easeOut(duration: 0.15), value: isFocused)

            TextField(
                "",
                text: Binding(
                    get: { viewModel.text },
                    set: { viewModel.setText($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 18, design: .monospaced))
            .foregroundStyle(ShellStyle.textPrimary)
            .tint(ShellStyle.accent)
            .focused($isFocused)
            .onSubmit { viewModel.submit() }
            .onKeyPress(.escape) {
                viewModel.escape()
                return .handled
            }
            // Take keyboard focus the instant the shell is summoned, so
            // the user can start typing without clicking. Setting it once
            // synchronously covers the case where the panel is already
            // key; re-asserting on the next runloop tick covers the race
            // where the non-activating panel only *becomes* key just
            // after this view mounts (otherwise the focus is dropped and
            // a click is needed).
            .onAppear {
                isFocused = true
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShellStyle.surfaceStrong)
        .overlay(alignment: .top) {
            Rectangle().fill(ShellStyle.hairline).frame(height: 1)
        }
    }
}
