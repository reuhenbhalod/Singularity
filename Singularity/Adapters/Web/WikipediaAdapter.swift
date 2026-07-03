//
//  WikipediaAdapter.swift
//  Singularity
//

import Foundation

/// Navigation-only Lane-2 adapter for Wikipedia. The planner emits a
/// `web_navigate` to an article or search URL; this adapter declares the
/// hosts so those URLs pass the allowlist.
struct WikipediaAdapter: WebAdapter {
    let allowedHosts = [
        "en.wikipedia.org",
        "wikipedia.org",
        "www.wikipedia.org",
    ]

    let dataStoreIdentifier =
        UUID(uuidString: "A1B2C3D4-0002-4000-8000-000000000002") ?? UUID()
}
