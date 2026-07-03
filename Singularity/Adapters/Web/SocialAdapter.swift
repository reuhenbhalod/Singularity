//
//  SocialAdapter.swift
//  Singularity
//

import Foundation

/// Navigation-only Lane-2 adapter for the common social sites (X /
/// Twitter, LinkedIn). Open a profile, a post, or the home feed; the
/// planner emits a `web_navigate` to the site. Its own persistent data
/// store keeps logins isolated and durable.
struct SocialAdapter: WebAdapter {
    let allowedHosts = [
        "x.com",
        "www.x.com",
        "twitter.com",
        "www.twitter.com",
        "mobile.twitter.com",
        "linkedin.com",
        "www.linkedin.com",
    ]

    let dataStoreIdentifier =
        UUID(uuidString: "A1B2C3D4-0004-4000-8000-000000000004") ?? UUID()

    let userAgent: String? =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}
