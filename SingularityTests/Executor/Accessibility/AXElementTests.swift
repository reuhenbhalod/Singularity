//
//  AXElementTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// A constructed AX tree for testing traversal without real
/// `AXUIElement`s (which need a live app + Accessibility permission).
@MainActor
private final class MockAXNode: AXNode {
    let roleString: String?
    let title: String?
    private let kids: [any AXNode]
    private(set) var performed: [AXAction] = []

    init(role: AXRole?, title: String? = nil, children: [any AXNode] = []) {
        self.roleString = role?.rawValue
        self.title = title
        self.kids = children
    }

    func children() throws -> [any AXNode] { kids }

    func perform(_ action: AXAction) throws { performed.append(action) }
}

@MainActor
struct AXElementTests {
    /// T-P4-02: the root for a running app resolves (no permission
    /// needed to create the handle). Finder is always running.
    @Test func applicationRootForRunningAppIsNonNil() {
        #expect(AXApplication(bundleId: "com.apple.finder") != nil)
    }

    /// A bundle ID with no running app resolves to nil.
    @Test func applicationRootForUnknownBundleIsNil() {
        #expect(AXApplication(bundleId: "com.singularity.not-running") == nil)
    }

    /// T-P4-02: findFirst locates a button by role and title.
    @Test func findFirstLocatesButtonByRoleAndTitle() throws {
        let tree = MockAXNode(
            role: .window,
            children: [
                MockAXNode(
                    role: .group,
                    children: [
                        MockAXNode(role: .button, title: "Cancel"),
                        MockAXNode(role: .button, title: "OK"),
                    ])
            ])

        let found = try tree.findFirst(role: .button, title: "OK")

        #expect(found?.title == "OK")
        #expect(found?.roleString == AXRole.button.rawValue)
    }

    /// No matching element -> nil.
    @Test func findFirstReturnsNilWhenNoMatch() throws {
        let tree = MockAXNode(role: .window, children: [MockAXNode(role: .button, title: "OK")])
        #expect(try tree.findFirst(role: .button, title: "Missing") == nil)
    }

    /// Without a title, findFirst returns the first element of the role.
    @Test func findFirstWithoutTitleMatchesFirstOfRole() throws {
        let tree = MockAXNode(
            role: .group,
            children: [
                MockAXNode(role: .staticText, title: "label"),
                MockAXNode(role: .button, title: "First"),
                MockAXNode(role: .button, title: "Second"),
            ])
        #expect(try tree.findFirst(role: .button)?.title == "First")
    }

    /// perform routes the action to the element.
    @Test func performRecordsAction() throws {
        let button = MockAXNode(role: .button, title: "OK")
        try button.perform(.press)
        #expect(button.performed == [.press])
    }
}
