//
//  PlaceholderPaneView.swift
//  Singularity
//

import SwiftUI

/// Phase 0 pane content: a labeled tile with a close button.
/// Real pane content (WKWebView, AX viewers, file viewers) lands
/// in T-P3 / T-P4. Until then, every pane the compositor knows
/// about is rendered with this view.
struct PlaceholderPaneView: View {
    let pane: Pane
    let onClose: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(pane.title)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button {
                    onClose(pane.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(pane.title)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .overlay(
                    Text("placeholder pane")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(4)
    }
}
