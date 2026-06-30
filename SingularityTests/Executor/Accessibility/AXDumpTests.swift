//
//  AXDumpTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// File-private mock tree (mirrors the one in `AXElementTests`).
@MainActor
private final class MockAXNode: AXNode {
    let roleString: String?
    let title: String?
    private let kids: [any AXNode]

    init(role: AXRole?, title: String? = nil, children: [any AXNode] = []) {
        self.roleString = role?.rawValue
        self.title = title
        self.kids = children
    }

    func children() throws -> [any AXNode] { kids }
    func perform(_ action: AXAction) throws {}
}

@MainActor
struct AXDumpTests {
    /// T-P4-08: renders an indented role/title tree, deepening with nesting.
    @Test func rendersIndentedTree() {
        let tree = MockAXNode(
            role: .window,
            title: "Main",
            children: [
                MockAXNode(role: .button, title: "OK"),
                MockAXNode(role: .group, children: [MockAXNode(role: .staticText, title: "Hi")]),
            ])

        let out = AXDump.render(tree)
        #expect(out.contains("AXWindow \"Main\""))
        #expect(out.contains("  AXButton \"OK\""))  // depth 1
        #expect(out.contains("    AXStaticText \"Hi\""))  // depth 2
    }

    /// A bundle id with no running app reports cleanly (no crash).
    @Test func dumpUnknownBundleReportsCleanly() {
        #expect(AXDump.dump(bundleId: "com.singularity.not-running").contains("No running app"))
    }
}
