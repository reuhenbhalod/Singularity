//
//  AllowedDomainsTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Minimal adapter for exercising the union with arbitrary hosts.
private struct FakeAdapter: WebAdapter {
    let allowedHosts: [String]
    let dataStoreIdentifier = UUID()
}

struct AllowedDomainsTests {
    /// T-P3-05: `all` is the lower-cased union of every adapter's hosts.
    @Test func unionsAdapterHostsLowercased() {
        let registry = AdapterRegistry(adapters: [
            FakeAdapter(allowedHosts: ["A.com", "b.COM"]),
            FakeAdapter(allowedHosts: ["c.com", "A.com"]),
        ])
        #expect(AllowedDomains(registry: registry).all == ["a.com", "b.com", "c.com"])
    }

    /// T-P3-05: `contains` is case-insensitive; the real YouTube host is
    /// present, others are not.
    @Test func containsIsCaseInsensitive() {
        let domains = AllowedDomains()
        #expect(domains.contains("WWW.YOUTUBE.COM"))
        #expect(domains.contains("www.youtube.com"))
        #expect(!domains.contains("example.com"))
    }

    /// T-P3-05: an IDN (`xn--`) host round-trips through the allowlist.
    @Test func idnHostRoundTrips() {
        let registry = AdapterRegistry(adapters: [FakeAdapter(allowedHosts: ["xn--n3h.example"])])
        let domains = AllowedDomains(registry: registry)
        #expect(domains.contains("xn--n3h.example"))
        #expect(domains.contains("XN--N3H.EXAMPLE"))
    }
}
