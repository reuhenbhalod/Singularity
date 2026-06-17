//
//  SingularityUITests.swift
//  SingularityUITests
//

import XCTest

/// Singularity uses `.accessory` activation policy (T-P0-02) and is summoned
/// via global hotkey (T-P0-03). `XCUIApplication().launch()` assumes a regular
/// foreground app with a Dock icon; that activation flow does not apply here.
/// Shell behavior is verified manually per the plan's §6 Test strategy. These
/// scaffold tests are skipped to keep `xcodebuild test` green; the target
/// itself is kept because removing it requires hand-editing project.pbxproj.
final class SingularityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        throw XCTSkip("Not applicable: Singularity is an .accessory hotkey app, not foreground-launchable.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        throw XCTSkip("Not applicable: Singularity is an .accessory hotkey app, not foreground-launchable.")
    }
}
