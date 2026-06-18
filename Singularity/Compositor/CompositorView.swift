//
//  CompositorView.swift
//  Singularity
//

import SwiftUI

/// Tiles the open panes for layouts of 1, 2, 3, or 4. Phase 0
/// renders every pane via `PlaceholderPaneView`. Future phases can
/// switch on pane kind to render real content.
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
                PlaceholderPaneView(pane: store.panes[0]) { store.remove(id: $0) }
            case 2:
                HStack(spacing: 0) {
                    PlaceholderPaneView(pane: store.panes[0]) { store.remove(id: $0) }
                    PlaceholderPaneView(pane: store.panes[1]) { store.remove(id: $0) }
                }
            case 3:
                HStack(spacing: 0) {
                    PlaceholderPaneView(pane: store.panes[0]) { store.remove(id: $0) }
                    VStack(spacing: 0) {
                        PlaceholderPaneView(pane: store.panes[1]) { store.remove(id: $0) }
                        PlaceholderPaneView(pane: store.panes[2]) { store.remove(id: $0) }
                    }
                }
            default:  // 4 or more (capped at 4 by store)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        PlaceholderPaneView(pane: store.panes[0]) { store.remove(id: $0) }
                        PlaceholderPaneView(pane: store.panes[1]) { store.remove(id: $0) }
                    }
                    HStack(spacing: 0) {
                        PlaceholderPaneView(pane: store.panes[2]) { store.remove(id: $0) }
                        PlaceholderPaneView(pane: store.panes[3]) { store.remove(id: $0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyState: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Text("no panes — type a command")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            )
    }
}
