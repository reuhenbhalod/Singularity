//
//  RiskClass.swift
//  Singularity
//

import Foundation

/// How consequential an action is — the axis safety scales on (brief
/// §11.2). `Comparable` so an adapter can *raise* a step's risk above the
/// default but never lower it (`max(default, override)`), and so the
/// gates can ask "is this at least Destructive?".
///
/// The gates that consume this — the confirm gate and the Touch ID
/// `AuthorizationGate` — arrive later in Phase 5 (T-P5-09/10); this is
/// the shared vocabulary they build on.
enum RiskClass: Int, Comparable, CaseIterable {
    /// Reads / launches: open a URL, read content. Flows through freely.
    case read = 0
    /// Undoable changes: drive an app, move a file to the trash, draft.
    case reversible = 1
    /// Irreversible changes: delete, overwrite. Confirm + Touch ID.
    case destructive = 2
    /// Spends money: place an order. Confirm + Touch ID, twice.
    case spend = 3

    static func < (lhs: RiskClass, rhs: RiskClass) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// One class harsher, capped at `.spend`. When untrusted content looks
    /// like an injection attempt, the next plan's risk is escalated by
    /// this so it faces a stricter gate (US-SAFE-6, §6 decision #4).
    var escalated: RiskClass {
        RiskClass(rawValue: rawValue + 1) ?? .spend
    }

    /// The default risk for an action before any adapter override. Every
    /// action that exists today only opens, reads, or drives playback —
    /// all `.read`, so nothing trips the confirm/Touch-ID gates. The
    /// higher classes attach to the file operations and the Amazon
    /// checkout in Phase 6 / the Amazon flow (an adapter may also raise a
    /// specific hook's risk).
    static func `default`(for action: Action) -> RiskClass {
        switch action {
        case .openURL, .webNavigate, .webEvaluate, .runScript, .axAction, .appleScript:
            return .read
        }
    }
}
