//
//  URLSchemeLaneTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Records opened URLs instead of launching apps.
@MainActor
private final class FakeURLOpener: URLOpening {
    private(set) var opened: [URL] = []
    var result = true

    func open(_ url: URL) -> Bool {
        opened.append(url)
        return result
    }
}

@MainActor
struct URLSchemeLaneTests {
    /// T-P3-03: a custom-scheme open_url dispatches via the opener.
    @Test func opensCustomScheme() async throws {
        let opener = FakeURLOpener()
        let lane = URLSchemeLane(opener: opener)
        let url = try #require(URL(string: "spotify:track:abc123"))
        let step = PlanStep(action: .openURL(url))

        #expect(lane.canHandle(step))
        let result = try await lane.execute(step)
        if case .handled = result {} else { Issue.record("expected .handled, got \(result)") }
        #expect(opener.opened == [url])
    }

    /// T-P3-03: an HTTPS open_url is not this lane's job (the web lane
    /// handles sites).
    @Test func rejectsHTTPS() throws {
        let lane = URLSchemeLane(opener: FakeURLOpener())
        let url = try #require(URL(string: "https://example.com"))
        #expect(!lane.canHandle(PlanStep(action: .openURL(url))))
    }

    /// It also ignores non-open_url actions.
    @Test func ignoresOtherActions() throws {
        let lane = URLSchemeLane(opener: FakeURLOpener())
        let url = try #require(URL(string: "https://www.youtube.com"))
        #expect(!lane.canHandle(PlanStep(action: .webNavigate(url))))
    }

    /// A failed open surfaces a "couldn't open" status.
    @Test func reportsFailedOpen() async throws {
        let opener = FakeURLOpener()
        opener.result = false
        let lane = URLSchemeLane(opener: opener)
        let url = try #require(URL(string: "mailto:someone@example.com"))

        let result = try await lane.execute(PlanStep(action: .openURL(url)))
        #expect(result == .handled(summary: "couldn't open mailto: link"))
    }
}
