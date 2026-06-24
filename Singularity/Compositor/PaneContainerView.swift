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
            HStack(spacing: 8) {
                Circle()
                    .fill(ShellStyle.accent.opacity(0.85))
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(ShellStyle.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    onClose(paneID)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ShellStyle.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(ShellStyle.surfaceStrong))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(title)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ShellStyle.surfaceStrong)

            // Fill the tile so the content (e.g. a WKWebView, which has
            // no intrinsic size) doesn't collapse to its header.
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: ShellStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ShellStyle.cornerRadius)
                .strokeBorder(ShellStyle.hairline, lineWidth: 1)
        )
        .padding(5)
    }
}
