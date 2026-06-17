//
//  SingularityTests.swift
//  SingularityTests
//

import AppKit
import Testing

@testable import Singularity

@MainActor
struct SingularityAppTests {
    /// T-P0-02 acceptance: AppDelegate sets `.accessory` activation policy
    /// at launch. Verified by invoking the lifecycle hook directly and
    /// reading NSApp's policy back.
    @Test func activationPolicyIsAccessoryAfterLaunch() async throws {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        #expect(NSApp.activationPolicy() == .accessory)
    }
}
