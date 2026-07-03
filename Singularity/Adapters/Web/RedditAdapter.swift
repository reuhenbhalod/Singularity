//
//  RedditAdapter.swift
//  Singularity
//

import Foundation

/// Navigation-only Lane-2 adapter for Reddit (open a subreddit or a
/// search). Its own persistent data store keeps a Reddit login isolated
/// and durable.
struct RedditAdapter: WebAdapter {
    let allowedHosts = [
        "www.reddit.com",
        "reddit.com",
        "old.reddit.com",
    ]

    let dataStoreIdentifier =
        UUID(uuidString: "A1B2C3D4-0003-4000-8000-000000000003") ?? UUID()

    /// Reddit sniffs the UA; use a desktop Safari string for the real site.
    let userAgent: String? =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}
