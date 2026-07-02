//
//  AccountTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct IdentityRecordTests {
    /// A private-relay email is detected (for the "(relayed)" label).
    @Test func detectsRelayedEmail() {
        #expect(
            IdentityRecord(user: "u", displayName: "A", email: "x@privaterelay.appleid.com")
                .emailIsRelayed)
        #expect(!IdentityRecord(user: "u", displayName: "A", email: "a@b.com").emailIsRelayed)
        #expect(!IdentityRecord(user: "u", displayName: "A", email: nil).emailIsRelayed)
    }

    /// The in-memory store round-trips and clears.
    @Test func inMemoryStoreRoundTrips() {
        let store = InMemoryIdentityStore()
        #expect(store.read() == nil)

        let record = IdentityRecord(user: "u1", displayName: "Abhiram", email: "a@b.com")
        store.write(record)
        #expect(store.read() == record)

        store.clear()
        #expect(store.read() == nil)
    }
}

@MainActor
struct AccountModelTests {
    /// T-P7-19: sign-in/out updates the observable state.
    @Test func signInOutUpdatesState() {
        let model = AccountModel(store: InMemoryIdentityStore())
        #expect(!model.isSignedIn)

        model.signIn(IdentityRecord(user: "u", displayName: "A", email: nil))
        #expect(model.isSignedIn)
        #expect(model.identity?.user == "u")

        model.signOut()
        #expect(!model.isSignedIn)
    }

    /// An existing identity is loaded at init.
    @Test func loadsExistingIdentity() {
        let store = InMemoryIdentityStore(IdentityRecord(user: "u", displayName: "A", email: nil))
        #expect(AccountModel(store: store).isSignedIn)
    }
}
