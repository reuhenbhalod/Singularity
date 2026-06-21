//
//  PaneContainerView.swift
//  Singularity
//

import SwiftUI

/// Shared pane chrome: a title bar with a close button, wrapping
/// arbitrary pane content. Both placeholder and web panes render
/// through this so the close affordance and framing stay identical.
struct PaneContainerView<Content: View>: View {
    let title: String
    let paneID: UUID
    let onClose: (UUID) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Button {
                    onClose(paneID)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(title)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))

            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(4)
    }
}
