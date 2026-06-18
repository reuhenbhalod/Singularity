//
//  ShellRootView.swift
//  Singularity
//

import SwiftUI

/// Three-region SwiftUI scaffolding for the shell pane:
/// session log strip on top, pane compositor in the middle, command
/// input on the bottom. Each region is a placeholder until the next
/// Phase 0 tasks fill them in (T-P0-08 command input, T-P0-09 session
/// log, T-P0-10 compositor).
///
/// Background uses `.ultraThinMaterial` so the panel looks like a
/// proper macOS overlay (Spotlight / Raycast aesthetic) once the
/// panel's own backgroundColor is cleared.
struct ShellRootView: View {
    var body: some View {
        VStack(spacing: 0) {
            SessionLogPlaceholder()
                .frame(height: 80)

            CompositorPlaceholder()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CommandInputPlaceholder()
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

private struct CommandInputPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .overlay(
                HStack {
                    Text(">")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("command input — T-P0-08")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 20)
            )
    }
}
