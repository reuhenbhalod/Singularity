//
//  ConfirmGate.swift
//  Singularity
//

import Foundation

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

/// Test/default gate that denies without asking (fail-safe). The real,
/// UI-presenting gate (`ConfirmGateView` bound to the shell) lands with
/// the first destructive/spend action; today's actions are all
/// read/reversible, so nothing reaches a confirm gate yet.
struct DenyingConfirmGate: ConfirmGate {
    func confirm(_ preview: ConfirmPreview) async -> Bool { false }
}
