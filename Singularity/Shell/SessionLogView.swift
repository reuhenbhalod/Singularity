//
//  SessionLogView.swift
//  Singularity
//

import SwiftUI

/// Renders the session log strip on top of the shell. Scrollable so
/// older entries are still reachable; auto-scrolls to the latest
/// entry on append. Styling is kept minimal in Phase 0; later phases
/// can add rich rendering (timestamps, colored badges, etc.).
struct SessionLogView: View {
    @Bindable var store: SessionLogStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.entries) { entry in
                        Text(prefix(for: entry.kind) + entry.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(color(for: entry.kind))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.never)
            .onChange(of: store.entries.count) { _, _ in
                if let last = store.entries.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.white.opacity(0.04))
    }

    private func prefix(for kind: SessionLogEntry.Kind) -> String {
        switch kind {
        case .command: return "> "
        case .system: return "· "
        case .result: return "  "
        }
    }

    private func color(for kind: SessionLogEntry.Kind) -> Color {
        switch kind {
        case .command: return Color.white.opacity(0.9)
        case .system: return Color.white.opacity(0.45)
        case .result: return Color.white.opacity(0.7)
        }
    }
}
