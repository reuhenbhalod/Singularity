//
//  PanicControllerTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

@MainActor
struct PanicControllerTests {
    /// T-P5-15: the panic phrase is matched trimmed + case-insensitive,
    /// and only when it's the whole input.
    @Test func recognizesPanicPhrase() {
        let panic = PanicController()
        #expect(panic.isPanicPhrase("abort"))
        #expect(panic.isPanicPhrase("  ABORT \n"))
        #expect(!panic.isPanicPhrase("abort the mission"))
    }

    /// Two Escs within the window trigger a panic; a lone Esc does not.
    @Test func doubleEscWithinWindow() {
        var clock = Date(timeIntervalSince1970: 0)
        let panic = PanicController(now: { clock })

        #expect(!panic.registerEsc())  // first Esc
        clock = Date(timeIntervalSince1970: 0.3)
        #expect(panic.registerEsc())  // within 0.5s -> panic
        clock = Date(timeIntervalSince1970: 5)
        #expect(!panic.registerEsc())  // window reset -> single Esc
    }

    /// Panicking cancels the tracked in-flight task.
    @Test func panicCancelsTrackedTask() async {
        let panic = PanicController()
        let task = Task {
            while !Task.isCancelled {
                await Task.yield()
            }
        }
        panic.track(task)
        panic.panic()
        await task.value
        #expect(task.isCancelled)
    }
}
