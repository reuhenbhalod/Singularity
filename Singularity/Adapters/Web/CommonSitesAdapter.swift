//
//  CommonSitesAdapter.swift
//  Singularity
//

import Foundation

/// Navigation-only Lane-2 adapter that broadens the allowlist to a curated
/// set of popular sites, so "open netflix", "open github", clicking a
/// mainstream search result, etc. actually load instead of being blocked.
///
/// These are browse targets only (no hooks); they share one persistent
/// data store like a single browser profile. The allowlist stays a curated
/// list by design (spec US-SAFE-3) — this just makes the common cases work.
/// The NSFW filter still runs ahead of the allowlist, so nothing here
/// bypasses it.
struct CommonSitesAdapter: WebAdapter {
    let allowedHosts = [
        // Search
        "duckduckgo.com", "www.duckduckgo.com",
        "bing.com", "www.bing.com",
        // Streaming / video
        "netflix.com", "www.netflix.com",
        "twitch.tv", "www.twitch.tv", "m.twitch.tv",
        "hulu.com", "www.hulu.com",
        "disneyplus.com", "www.disneyplus.com",
        "primevideo.com", "www.primevideo.com",
        "music.youtube.com",
        "soundcloud.com", "www.soundcloud.com",
        "music.apple.com",
        // Shopping
        "amazon.com", "www.amazon.com", "smile.amazon.com",
        "ebay.com", "www.ebay.com",
        "etsy.com", "www.etsy.com",
        "bestbuy.com", "www.bestbuy.com",
        // Dev / work
        "github.com", "www.github.com", "gist.github.com",
        "gitlab.com", "www.gitlab.com",
        "stackoverflow.com",
        "notion.so", "www.notion.so",
        "docs.google.com", "drive.google.com", "sheets.google.com",
        "calendar.google.com",
        // News / reference
        "cnn.com", "www.cnn.com",
        "bbc.com", "www.bbc.com", "bbc.co.uk", "www.bbc.co.uk",
        "nytimes.com", "www.nytimes.com",
        "theverge.com", "www.theverge.com",
        "arstechnica.com", "www.arstechnica.com",
        "imdb.com", "www.imdb.com",
        "weather.com", "www.weather.com",
        "espn.com", "www.espn.com",
        // Social / media
        "instagram.com", "www.instagram.com",
        "facebook.com", "www.facebook.com",
        "tiktok.com", "www.tiktok.com",
        "pinterest.com", "www.pinterest.com",
        // Maps / travel
        "maps.apple.com",
        "openstreetmap.org", "www.openstreetmap.org",
    ]

    let dataStoreIdentifier =
        UUID(uuidString: "A1B2C3D4-0005-4000-8000-000000000005") ?? UUID()

    /// Some of these sites sniff the UA; a desktop Safari string renders the
    /// real site rather than a "download our app" wall.
    let userAgent: String? =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/18.3 Safari/605.1.15"
}
