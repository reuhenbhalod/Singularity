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
        HStack(spacing: 12) {
            Text(">")
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            TextField(
                "",
                text: Binding(
                    get: { viewModel.text },
                    set: { viewModel.setText($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(.title3, design: .monospaced))
            .foregroundStyle(.white)
            .focused($isFocused)
            .onSubmit { viewModel.submit() }
            .onKeyPress(.escape) {
                viewModel.escape()
                return .handled
            }
            .onAppear { isFocused = true }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.06))
    }
}
