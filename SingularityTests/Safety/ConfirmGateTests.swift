//
//  ConfirmGateTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct ConfirmGateTests {
    /// T-P5-10: the shell gate publishes the preview, then Confirm
    /// resolves the suspended caller with `true`.
    @Test func confirmApproves() async {
        let gate = ShellConfirmGate()
        let pending = Task { await gate.confirm(ConfirmPreview(title: "t", detail: "d")) }
        while gate.pending == nil { await Task.yield() }

        #expect(gate.pending?.title == "t")
        gate.resolve(true)
        #expect(await pending.value == true)
        #expect(gate.pending == nil)
    }

    /// Cancel resolves with `false`.
    @Test func cancelDenies() async {
        let gate = ShellConfirmGate()
        let pending = Task { await gate.confirm(ConfirmPreview(title: "t", detail: "d")) }
        while gate.pending == nil { await Task.yield() }

        gate.resolve(false)
        #expect(await pending.value == false)
    }

    /// The fail-safe default gate denies without asking.
    @Test func denyingGateDenies() async {
        let denied = await DenyingConfirmGate().confirm(ConfirmPreview(title: "t", detail: "d"))
        #expect(denied == false)
    }
}
