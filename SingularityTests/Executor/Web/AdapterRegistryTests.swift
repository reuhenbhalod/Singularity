//
//  AdapterRegistryTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct AdapterRegistryTests {
    /// T-P3-04: lookup finds the adapter that declares the host.
    @Test func lookupFindsAdapterByHost() throws {
        let adapter = try #require(AdapterRegistry().lookup(host: "www.youtube.com"))
        #expect(adapter is YouTubeAdapter)
    }

    /// Lookup is case-insensitive.
    @Test func lookupIsCaseInsensitive() throws {
        let adapter = try #require(AdapterRegistry().lookup(host: "WWW.YOUTUBE.COM"))
        #expect(adapter is YouTubeAdapter)
    }

    /// Unknown hosts resolve to nil.
    @Test func lookupReturnsNilForUnknownHost() {
        #expect(AdapterRegistry().lookup(host: "example.com") == nil)
    }

    /// The default registry collects the declared adapters.
    @Test func collectsDeclaredAdapters() {
        #expect(AdapterRegistry().adapters.contains { $0 is YouTubeAdapter })
    }
}
