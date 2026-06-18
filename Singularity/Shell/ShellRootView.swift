//
//  ShellRootView.swift
//  Singularity
//

import SwiftUI

/// Three-region SwiftUI scaffolding for the shell pane:
/// session log strip on top, pane compositor in the middle, command
/// input on the bottom. Command input is wired via T-P0-08; the log
/// strip and compositor are still placeholders until T-P0-09 and
/// T-P0-10.
struct ShellRootView: View {
    @Bindable var commandInputViewModel: CommandInputViewModel

    var body: some View {
        VStack(spacing: 0) {
            SessionLogPlaceholder()
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

private struct SessionLogPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .overlay(
                Text("session log — T-P0-09")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            )
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
