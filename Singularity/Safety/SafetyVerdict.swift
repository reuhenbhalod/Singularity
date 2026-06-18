//
//  SafetyVerdict.swift
//  Singularity
//

import Foundation

/// The decision a safety gate returns for a single plan step.
/// Phase 1 only uses `.allow` (because the gate isn't real yet).
/// Phase 5 adds `.deny`, `.requireConfirm`, and `.requireTouchID`
/// per research brief §6 and §11.
enum SafetyVerdict: Equatable {
    case allow
    // Phase 5 additions:
    //   case deny(reason: String)
    //   case requireConfirm(preview: String)
    //   case requireTouchID
}
