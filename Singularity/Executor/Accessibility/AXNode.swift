//
//  AXNode.swift
//  Singularity
//

import Foundation

/// One node in an Accessibility tree. Abstracted as a protocol so the
/// traversal logic (`findFirst`) can be unit-tested against a mock tree
/// without real `AXUIElement`s — constructing those requires a live app
/// and Accessibility permission.
///
/// `@MainActor` because the real implementation makes synchronous AX IPC
/// calls and the executor's AX work is main-actor-confined.
@MainActor
protocol AXNode {
    /// The element's role string (e.g. `"AXButton"`), or nil.
    var roleString: String? { get }
    /// The element's title/label, or nil.
    var title: String? { get }
    /// Direct children. Throws on an AX failure (e.g. permission denied).
    func children() throws -> [any AXNode]
    /// Performs an action on the element.
    func perform(_ action: AXAction) throws
}

extension AXNode {
    /// Depth-first search for the first element (including self) matching
    /// `role`, and `title` when one is given. Returns nil if none match.
    func findFirst(role: AXRole, title: String? = nil) throws -> (any AXNode)? {
        if roleString == role.rawValue, title == nil || self.title == title {
            return self
        }
        for child in try children() {
            if let match = try child.findFirst(role: role, title: title) {
                return match
            }
        }
        return nil
    }
}
