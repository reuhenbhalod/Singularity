//
//  ShellRootView.swift
//  Singularity
//

import SwiftUI

/// Three-region SwiftUI scaffolding for the shell pane:
/// session log strip on top (T-P0-09), pane compositor in the middle
/// (T-P0-10), command input on the bottom (T-P0-08).
struct ShellRootView: View {
    @Bindable var commandInputViewModel: CommandInputViewModel
    @Bindable var sessionLog: SessionLogStore

    var body: some View {
        VStack(spacing: 0) {
            SessionLogView(store: sessionLog)
                .frame(height: 80)

            CompositorPlaceholder()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CommandInputView(viewModel: commandInputViewModel)
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
}

private struct CompositorPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Text("pane compositor — T-P0-10")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.25))
            )
    }
}
