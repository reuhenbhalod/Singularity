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
    @Bindable var compositor: CompositorStore

    var body: some View {
        VStack(spacing: 0) {
            SessionLogView(store: sessionLog)
                .frame(height: 80)

            CompositorView(store: compositor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CommandInputView(viewModel: commandInputViewModel)
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
}
