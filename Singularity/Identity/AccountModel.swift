//
//  AccountModel.swift
//  Singularity
//

import Observation

/// Observable account state for the Account settings tab — the current
/// identity plus sign-in/out, backed by an `IdentityStore`.
@MainActor
@Observable
final class AccountModel {
    private(set) var identity: IdentityRecord?

    @ObservationIgnored private let store: any IdentityStore

    init(store: any IdentityStore = KeychainIdentityStore()) {
        self.store = store
        self.identity = store.read()
    }

    var isSignedIn: Bool { identity != nil }

    func signIn(_ record: IdentityRecord) {
        store.write(record)
        identity = record
    }

    func signOut() {
        store.clear()
        identity = nil
    }
}
