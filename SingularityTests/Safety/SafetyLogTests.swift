//
//  SafetyLogTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct SafetyLogTests {
    /// T-P3-12: logs under the app subsystem and the `safety` category.
    /// (OSLog output itself is verified manually via `log show`.)
    @Test func usesExpectedSubsystemAndCategory() {
        #expect(SafetyLog.subsystem == "com.reuhenbhalod.Singularity")
        #expect(SafetyLog.category == "safety")
    }

    /// `urlDenied` is callable without crashing.
    @Test func urlDeniedIsCallable() throws {
        SafetyLog.urlDenied(host: "evil.example", url: try #require(URL(string: "https://evil.example/x")))
    }
}
