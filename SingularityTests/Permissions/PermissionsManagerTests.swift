//
//  PermissionsManagerTests.swift
//  SingularityTests
//

import ApplicationServices
import Testing

@testable import Singularity

@MainActor
struct PermissionsManagerTests {
    /// T-P4-09: granted when the app is a trusted Accessibility client.
    @Test func grantedWhenTrusted() {
        #expect(PermissionsManager(isTrusted: { true }).accessibility == .granted)
    }

    /// T-P4-09: denied otherwise.
    @Test func deniedWhenNotTrusted() {
        #expect(PermissionsManager(isTrusted: { false }).accessibility == .denied)
    }

    /// The default reflects the live `AXIsProcessTrusted()` value
    /// (whatever the test host's grant state happens to be).
    @Test func defaultMatchesLiveTrustCheck() {
        let expected: PermissionsManager.Status = AXIsProcessTrusted() ? .granted : .denied
        #expect(PermissionsManager().accessibility == expected)
    }
}
