//
//  PlaceholderPaneView.swift
//  Singularity
//

import SwiftUI

/// Placeholder pane content (no chrome — `PaneContainerView` supplies
/// the title bar and close button). Used for panes that have no real
/// content yet; web panes render `WebPaneView` instead.
struct PlaceholderPaneView: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .overlay(
                Text("placeholder pane")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            )
    }
}
