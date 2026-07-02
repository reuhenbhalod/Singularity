//
//  MailAXAdapter.swift
//  Singularity
//

import Foundation

/// Reads from the Mail.app desktop client via Accessibility (research
/// brief §5). Phase 4 supports one hook — `read_latest` — returning the
/// subject of the newest message in the open message list.
///
/// Mail shows the message list newest-first, so the first row is the
/// latest. The subject-extraction heuristic (below) is tuned against the
/// live Mail AX tree; use the `axdump` debug command (T-P4-08) to inspect
/// it when Mail's layout shifts.
///
/// The returned subject is **untrusted content** (it originates outside
/// the app). It is only shown in the session log here — never a planner
/// prompt — so it's surfaced raw. Any future read-then-plan flow (e.g.
/// "read my mail and draft a reply") MUST route it through
/// `UntrustedContentFilter.wrap(...)` first (that wrap point exists as of
/// Phase 5); a bare `String` can't enter planner context.
struct MailAXAdapter: AXAdapter {
    let name = "mail"
    let bundleID = "com.apple.mail"
    let hooks: Set<String> = ["read_latest"]

    @MainActor
    func perform(_ hook: String, in app: AXApplication) throws -> String {
        switch hook {
        case "read_latest":
            guard let subject = try Self.latestSubject(in: app.root) else {
                return "couldn't find any messages in Mail"
            }
            return "latest email: \(subject)"
        default:
            throw AXErrors.actionUnsupported
        }
    }

    /// Returns the newest message's subject from a Mail AX tree, or `nil`
    /// if no message row is found.
    ///
    /// Extracted as a static over `any AXNode` so the traversal is
    /// unit-testable against a mock tree — building real `AXUIElement`s
    /// needs a running, populated Mail and Accessibility permission, so
    /// the live path is verified manually.
    ///
    /// Heuristic: the first row is the newest message; a row exposes
    /// several `AXStaticText` labels (sender, subject, date, preview).
    /// The subject is taken as the longest label, which empirically
    /// separates it from the short sender/date and is more stable than a
    /// positional guess across Mail layouts.
    @MainActor
    static func latestSubject(in root: any AXNode) throws -> String? {
        guard let firstRow = try root.findFirst(role: .row) else { return nil }
        let labels = try staticTextLabels(in: firstRow)
        return labels.max(by: { $0.count < $1.count })
    }

    /// Collects every non-empty `AXStaticText` title under `node`.
    @MainActor
    private static func staticTextLabels(in node: any AXNode) throws -> [String] {
        var labels: [String] = []
        if node.roleString == AXRole.staticText.rawValue,
            let title = node.title, !title.isEmpty
        {
            labels.append(title)
        }
        for child in try node.children() {
            labels.append(contentsOf: try staticTextLabels(in: child))
        }
        return labels
    }
}
