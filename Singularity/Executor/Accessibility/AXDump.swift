//
//  AXDump.swift
//  Singularity
//

import Foundation

/// Renders a running app's Accessibility tree as indented text — the
/// tool adapter authors use to discover the roles/titles to target
/// (research brief §5, T-P4-08). Invoked inline as `axdump <bundle id>`;
/// the Settings "Advanced" surface lands with the Settings scene in
/// Phase 7.
enum AXDump {
    /// Max depth walked, so a deep app tree can't produce unbounded
    /// output in the session log.
    static let maxDepth = 14

    /// Dumps the AX tree of the running app with `bundleId`, or a clean
    /// message if it isn't running. Reading the tree needs Accessibility
    /// permission; without it only the root line comes back.
    @MainActor
    static func dump(bundleId: String) -> String {
        guard let app = AXApplication(bundleId: bundleId) else {
            return "No running app with bundle id \"\(bundleId)\"."
        }
        return render(app.root)
    }

    /// Renders `node` and its descendants as indented `role "title"`
    /// lines. Static over `any AXNode` so it's unit-testable against a
    /// mock tree (a live `AXUIElement` needs a running app + permission).
    @MainActor
    static func render(_ node: any AXNode, depth: Int = 0) -> String {
        let pad = String(repeating: "  ", count: depth)
        let role = node.roleString ?? "(no role)"
        let title = node.title.map { " \"\($0)\"" } ?? ""
        var out = "\(pad)\(role)\(title)\n"
        guard depth < maxDepth else {
            return out + "\(pad)  …(truncated)\n"
        }
        let children = (try? node.children()) ?? []
        for child in children {
            out += render(child, depth: depth + 1)
        }
        return out
    }
}
