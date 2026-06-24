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
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(glyph(for: entry.kind))
                                .foregroundStyle(glyphColor(for: entry.kind))
                            Text(entry.text)
                                .foregroundStyle(color(for: entry.kind))
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .font(.system(.caption, design: .monospaced))
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)
            .onChange(of: store.entries.count) { _, _ in
                if let last = store.entries.last {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(ShellStyle.surface)
    }

    private func glyph(for kind: SessionLogEntry.Kind) -> String {
        switch kind {
        case .command: return "›"
        case .system: return "·"
        case .result: return "↳"
        }
    }

    private func glyphColor(for kind: SessionLogEntry.Kind) -> Color {
        switch kind {
        case .command: return ShellStyle.accent
        case .system: return ShellStyle.textTertiary
        case .result: return ShellStyle.textTertiary
        }
    }

    private func color(for kind: SessionLogEntry.Kind) -> Color {
        switch kind {
        case .command: return ShellStyle.textPrimary
        case .system: return ShellStyle.textTertiary
        case .result: return ShellStyle.textSecondary
        }
    }
}
