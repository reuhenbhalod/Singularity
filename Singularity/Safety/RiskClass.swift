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

    /// The default risk for an action before any adapter override. The
    /// actions that exist today only read or reversibly drive an app;
    /// destructive/spend land with the file and checkout actions in
    /// Phase 6 / the Amazon flow.
    static func `default`(for action: Action) -> RiskClass {
        switch action {
        case .openURL, .webNavigate, .webEvaluate:
            return .read
        case .runScript, .axAction:
            return .reversible
        }
    }
}
