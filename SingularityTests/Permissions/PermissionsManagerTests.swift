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
        #expect(PermissionsManager(isTrusted: { true }, fdaProbe: { .granted }).accessibility == .granted)
    }

    /// T-P4-09: denied otherwise.
    @Test func deniedWhenNotTrusted() {
        #expect(PermissionsManager(isTrusted: { false }, fdaProbe: { .granted }).accessibility == .denied)
    }

    /// The default reflects the live `AXIsProcessTrusted()` value
    /// (whatever the test host's grant state happens to be).
    @Test func defaultMatchesLiveTrustCheck() {
        let expected: PermissionsManager.Status = AXIsProcessTrusted() ? .granted : .denied
        #expect(PermissionsManager().accessibility == expected)
    }

    /// T-P7-06: the injected Full Disk Access probe drives FDA status.
    @Test func fullDiskAccessReflectsProbe() {
        #expect(PermissionsManager(isTrusted: { true }, fdaProbe: { .denied }).fullDiskAccess == .denied)
        #expect(PermissionsManager(isTrusted: { true }, fdaProbe: { .granted }).fullDiskAccess == .granted)
    }

    /// T-P7-06: Automation starts unknown and folds AppleScript results
    /// in — success → granted, -1743 → denied, other codes → unchanged.
    @Test func automationCacheTracksAppleScriptResults() {
        let manager = PermissionsManager(isTrusted: { true }, fdaProbe: { .granted })
        #expect(manager.automation == .unknown)

        manager.recordAutomationResult(errorCode: nil)
        #expect(manager.automation == .granted)

        manager.recordAutomationResult(errorCode: -1743)
        #expect(manager.automation == .denied)

        // An unrelated error doesn't flip the cached state.
        manager.recordAutomationResult(errorCode: -600)
        #expect(manager.automation == .denied)
    }

    /// `deniedKinds` lists exactly the denied permissions.
    @Test func deniedKindsReportsDeniedOnly() {
        let manager = PermissionsManager(isTrusted: { false }, fdaProbe: { .granted })
        manager.recordAutomationResult(errorCode: nil)
        #expect(manager.deniedKinds == [.accessibility])
        #expect(manager.hasDeniedPermission)
    }

    /// T-P7-07: System Settings deep links carry the right privacy anchor.
    @Test func settingsLinksTargetCorrectPanes() {
        #expect(
            SystemSettingsLinks.url(for: .accessibility).absoluteString.contains("Privacy_Accessibility"))
        #expect(SystemSettingsLinks.url(for: .automation).absoluteString.contains("Privacy_Automation"))
        #expect(SystemSettingsLinks.url(for: .fullDiskAccess).absoluteString.contains("Privacy_AllFiles"))
    }
}
