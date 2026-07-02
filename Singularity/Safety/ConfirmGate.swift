//
//  ConfirmGate.swift
//  Singularity
//

import Foundation
import Observation

/// A plain-English preview of a mutating action, shown before it runs
/// (brief §11 / `Singularity.md` §6). e.g. title "Place order", detail
/// "Sony WH-1000XM5 — $349.99 to your default address".
struct ConfirmPreview: Equatable {
    let title: String
    let detail: String
}

/// Asks the user to confirm a destructive/spend action, returning whether
/// they approved. Never auto-proceeds — confirmation is required even
/// after Touch ID succeeds (US-SAFE-5).
protocol ConfirmGate {
    func confirm(_ preview: ConfirmPreview) async -> Bool
}

/// Fail-safe default gate that denies without asking. Used where no UI is
/// wired; the shell injects `ShellConfirmGate` instead.
struct DenyingConfirmGate: ConfirmGate {
    func confirm(_ preview: ConfirmPreview) async -> Bool { false }
}

/// The shell's confirm gate: publishes the `pending` preview so
/// `ConfirmGateView` can render it, and suspends the caller until the
/// user taps Confirm/Cancel. Nothing reaches it yet (today's actions are
/// all `.read`); it goes live when Phase 6 adds destructive/spend actions.
@MainActor
@Observable
final class ShellConfirmGate: ConfirmGate {
    /// The preview currently awaiting a decision, or `nil`.
    private(set) var pending: ConfirmPreview?

    @ObservationIgnored private var continuation: CheckedContinuation<Bool, Never>?

    func confirm(_ preview: ConfirmPreview) async -> Bool {
        await withCheckedContinuation { continuation in
            self.pending = preview
            self.continuation = continuation
        }
    }

    /// Resolves the pending confirmation (from the view's buttons).
    func resolve(_ approved: Bool) {
        pending = nil
        continuation?.resume(returning: approved)
        continuation = nil
    }
}
