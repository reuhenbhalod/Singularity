//
//  PanicController.swift
//  Singularity
//

import Foundation

/// Hard-stop for an in-flight command (US-SAFE-7). Typing the panic
/// phrase (`abort` by default) or double-Esc cancels the running executor
/// task via `Task.cancel()`. The double-Esc timing lives in the input
/// view; this controller owns phrase recognition and cancellation.
@MainActor
final class PanicController {
    /// The phrase that triggers a cancel (configurable in Settings).
    var panicPhrase: String = "abort"

    /// Max gap between two Escs to count as a double-Esc.
    static let doubleEscWindow: TimeInterval = 0.5

    private var inFlight: Task<Void, Never>?
    private var lastEsc: Date?
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Tracks the currently-running command task so it can be cancelled.
    func track(_ task: Task<Void, Never>) {
        inFlight = task
    }

    /// Whether `input` is the panic phrase (trimmed, case-insensitive).
    func isPanicPhrase(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == panicPhrase.lowercased()
    }

    /// Records an Esc; returns whether it completed a double-Esc within
    /// the window (and should therefore panic).
    func registerEsc() -> Bool {
        let time = now()
        defer { lastEsc = time }
        if let previous = lastEsc, time.timeIntervalSince(previous) <= Self.doubleEscWindow {
            lastEsc = nil
            return true
        }
        return false
    }

    /// Cancels the in-flight task, if any, and logs the panic.
    func panic() {
        inFlight?.cancel()
        inFlight = nil
        SafetyLog.panicCancelled()
    }
}
