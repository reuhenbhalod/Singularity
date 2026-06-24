//
//  CompositorView.swift
//  Singularity
//

import SwiftUI

/// Tiles the open panes for layouts of 1, 2, 3, or 4. Each pane is
/// rendered by `PaneView`, which dispatches on the pane's kind
/// (placeholder vs. live web pane).
///
/// Layouts:
/// - 1 pane: full bleed.
/// - 2 panes: 50/50 horizontal split.
/// - 3 panes: left half = pane 0; right half split top/bottom for
///   panes 1 and 2.
/// - 4 panes: 2 × 2 grid.
struct CompositorView: View {
    @Bindable var store: CompositorStore

    var body: some View {
        Group {
            switch store.panes.count {
            case 0:
                EmptyState()
            case 1:
                PaneView(pane: store.panes[0]) { store.remove(id: $0) }
            case 2:
                HStack(spacing: 0) {
                    PaneView(pane: store.panes[0]) { store.remove(id: $0) }
                    PaneView(pane: store.panes[1]) { store.remove(id: $0) }
                }
            case 3:
                HStack(spacing: 0) {
                    PaneView(pane: store.panes[0]) { store.remove(id: $0) }
                    VStack(spacing: 0) {
                        PaneView(pane: store.panes[1]) { store.remove(id: $0) }
                        PaneView(pane: store.panes[2]) { store.remove(id: $0) }
                    }
                }
            default:  // 4 or more (capped at 4 by store)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        PaneView(pane: store.panes[0]) { store.remove(id: $0) }
                        PaneView(pane: store.panes[1]) { store.remove(id: $0) }
                    }
                    HStack(spacing: 0) {
                        PaneView(pane: store.panes[2]) { store.remove(id: $0) }
                        PaneView(pane: store.panes[3]) { store.remove(id: $0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The idle state of the shell. Shows a calm wordmark and a rotating
/// suggestion that changes on every summon — so the empty shell never
/// looks the same twice and the hint doubles as onboarding (every
/// suggestion is a command that actually works).
private struct EmptyState: View {
    @State private var hint = EmptyState.nextHint()

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "command")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(ShellStyle.textTertiary)

            VStack(spacing: 7) {
                Text("Singularity")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(ShellStyle.textSecondary)
                Text("Try “\(hint)”")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(ShellStyle.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    /// Real, working commands — they rotate so each launch differs and
    /// the user always sees something they can actually type.
    private static let hints = [
        "play mrbeast's newest video",
        "play the latest from veritasium",
        "play marques brownlee's newest video",
        "play the newest mkbhd video",
        "play kai cenat's latest video",
        "play the stradman's newest video",
        "play the latest from linus tech tips",
        "open youtube and play the newest mrwhosetheboss",
    ]

    /// Advances a persisted index so the suggestion is different on every
    /// summon (and across restarts). UserDefaults keeps this trivially
    /// concurrency-safe — no shared mutable state.
    private static func nextHint() -> String {
        let key = "shell.emptyStateHintIndex"
        let next = (UserDefaults.standard.integer(forKey: key) + 1) % hints.count
        UserDefaults.standard.set(next, forKey: key)
        return hints[next]
    }
}
