//
//  GmailAdapter.swift
//  Singularity
//

import Foundation

/// Lane-2 adapter for Gmail. Phase 3 is navigation-only (open the
/// inbox); read/compose hooks arrive in a later phase.
///
/// It has its own persistent `WKWebsiteDataStore` (separate from
/// YouTube's) so a Gmail login persists across launches and stays
/// isolated from other adapters. `allowedHosts` covers the inbox plus
/// the Google sign-in hosts the login flow navigates through.
struct GmailAdapter: WebAdapter {
    let allowedHosts = [
        "mail.google.com",
        "accounts.google.com",
        "www.google.com",
        "google.com",
    ]

    /// Fixed identifier for Gmail's isolated, persistent data store.
    let dataStoreIdentifier =
        UUID(uuidString: "C1D2E3F4-A5B6-4C7D-8E9F-0A1B2C3D4E5F") ?? UUID()
}
