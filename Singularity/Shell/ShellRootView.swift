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
    @Bindable var confirmGate: ShellConfirmGate

    var body: some View {
        VStack(spacing: 0) {
            // The log strip only appears once there's something to show,
            // so an idle shell is just the centered hint and the line.
            if !sessionLog.entries.isEmpty {
                SessionLogView(store: sessionLog)
                    .frame(maxHeight: 140)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(ShellStyle.hairline).frame(height: 1)
            }

            CompositorView(store: compositor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CommandInputView(viewModel: commandInputViewModel)
                .frame(height: 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.black.opacity(0.32))
            }
            .ignoresSafeArea()
        }
        .animation(.easeOut(duration: 0.15), value: sessionLog.entries.isEmpty)
        .overlay { ConfirmGateView(gate: confirmGate) }
        .preferredColorScheme(.dark)
    }
}
