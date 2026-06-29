//
//  MailAXAdapterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// A constructed AX tree for testing the subject heuristic without real
/// `AXUIElement`s (file-private; mirrors the mock in `AXElementTests`).
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
struct MailAXAdapterTests {
    /// T-P4-06: the Mail adapter declares the read_latest hook and the
    /// right bundle ID.
    @Test func declaresReadLatestHookAndBundle() {
        let adapter = MailAXAdapter()
        #expect(adapter.name == "mail")
        #expect(adapter.bundleID == "com.apple.mail")
        #expect(adapter.hooks.contains("read_latest"))
    }

    /// The subject heuristic takes the longest label in the newest row,
    /// separating the subject from the short sender/date labels.
    @Test func latestSubjectPicksTheSubjectFromTheFirstRow() throws {
        let tree = MockAXNode(
            role: .window,
            children: [
                MockAXNode(
                    role: .row,
                    children: [
                        MockAXNode(role: .staticText, title: "Alice"),
                        MockAXNode(role: .staticText, title: "Q3 roadmap planning sync"),
                        MockAXNode(role: .staticText, title: "9:41 AM"),
                    ]),
                MockAXNode(role: .row, children: [MockAXNode(role: .staticText, title: "older")]),
            ])

        #expect(try MailAXAdapter.latestSubject(in: tree) == "Q3 roadmap planning sync")
    }

    /// No message rows -> nil (the adapter surfaces a clean status).
    @Test func latestSubjectIsNilWhenNoRows() throws {
        let empty = MockAXNode(role: .window, children: [MockAXNode(role: .group)])
        #expect(try MailAXAdapter.latestSubject(in: empty) == nil)
    }
}
