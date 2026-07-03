//
//  GoogleAdapter.swift
//  Singularity
//

import Foundation

/// Navigation-only Lane-2 adapter for Google Search and Google Maps. The
/// planner emits a `web_navigate` to a `google.com/search?q=…` or
/// `google.com/maps/…` URL; this adapter just declares the hosts so those
/// URLs pass the allowlist.
struct GoogleAdapter: WebAdapter {
    let allowedHosts = [
        "www.google.com",
        "google.com",
        "maps.google.com",
    ]

    let dataStoreIdentifier =
        UUID(uuidString: "A1B2C3D4-0001-4000-8000-000000000001") ?? UUID()
}
