//
//  AXObservationTests.swift
//  SingularityTests
//

import ApplicationServices
import Foundation
import Testing

@testable import Singularity

@MainActor
struct AXObservationTests {
    /// T-P4-03 groundwork: the app handle exposes the pid an observer
    /// needs. Finder is always running.
    @Test func applicationExposesPid() throws {
        let app = try #require(AXApplication(bundleId: "com.apple.finder"))
        #expect(app.pid > 0)
    }

    /// Constructing a stream for an un-observable target doesn't crash
    /// (live event delivery is verified manually on a real app).
    @Test func streamForInvalidTargetConstructsCleanly() {
        let element = AXUIElementCreateApplication(0)
        _ = AXObservation.stream(
            pid: 0,
            element: element,
            notification: kAXFocusedUIElementChangedNotification as String)
        #expect(Bool(true))
    }
}
