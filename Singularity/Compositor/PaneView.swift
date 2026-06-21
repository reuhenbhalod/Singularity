//
//  PaneView.swift
//  Singularity
//

import SwiftUI

/// Renders one pane: shared chrome from `PaneContainerView` wrapping
/// content chosen by the pane's `kind`. The compositor tiles these.
struct PaneView: View {
    let pane: Pane
    let onClose: (UUID) -> Void

    var body: some View {
        PaneContainerView(title: pane.title, paneID: pane.id, onClose: onClose) {
            switch pane.kind {
            case .placeholder:
                PlaceholderPaneView()
            case .web(let controller):
                WebPaneView(controller: controller)
            }
        }
    }
}
