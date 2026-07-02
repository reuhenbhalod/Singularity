//
//  IdentityRecord.swift
//  Singularity
//

import Foundation

/// The minimal identity Singularity keeps after Sign in with Apple
/// (brief §12.1). Only the stable user id and the optional name/email are
/// stored — never the `identityToken` or `authorizationCode`.
struct IdentityRecord: Codable, Equatable {
    let user: String
    let displayName: String?
    let email: String?

    /// Whether the email is an Apple private-relay address.
    var emailIsRelayed: Bool {
        email?.hasSuffix("privaterelay.appleid.com") ?? false
    }
}
