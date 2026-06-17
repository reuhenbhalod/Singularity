//
//  SingularityUITestsLaunchTests.swift
//  SingularityUITests
//

import XCTest

/// See `SingularityUITests` for the rationale: `.accessory` activation does
/// not support `XCUIApplication().launch()`, so the launch-screenshot test is
/// skipped. Manual verification covers the shell-summon flow.
final class SingularityUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        throw XCTSkip("Not applicable: Singularity is an .accessory hotkey app, not foreground-launchable.")
    }
}
