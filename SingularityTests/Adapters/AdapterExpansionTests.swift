//
//  AdapterExpansionTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct WebAdapterExpansionTests {
    /// The new navigation targets are on the allowlist so the planner's
    /// web_navigate URLs actually load.
    @Test func newHostsAreAllowlisted() {
        let domains = AllowedDomains()
        for host in [
            "www.google.com", "google.com", "maps.google.com",
            "en.wikipedia.org", "wikipedia.org",
            "www.reddit.com", "reddit.com",
            "x.com", "twitter.com", "www.linkedin.com",
        ] {
            #expect(domains.contains(host), "expected \(host) to be allowlisted")
        }
    }

    /// Host lookup resolves the new adapters.
    @Test func lookupResolvesNewAdapters() {
        let registry = AdapterRegistry()
        #expect(registry.lookup(host: "en.wikipedia.org") is WikipediaAdapter)
        #expect(registry.lookup(host: "www.reddit.com") is RedditAdapter)
        #expect(registry.lookup(host: "x.com") is SocialAdapter)
    }

    /// Every web adapter's persistent data-store identifier is unique —
    /// a collision would let two sites share cookies/logins.
    @Test func dataStoreIdentifiersAreUnique() {
        let ids = AdapterRegistry.defaultAdapters.map(\.dataStoreIdentifier)
        #expect(Set(ids).count == ids.count)
    }
}

struct SystemAppleScriptAdapterTests {
    /// The system adapter is registered under the planner-facing name.
    @Test func systemAdapterIsRegistered() {
        #expect(AppleScriptAdapterRegistry().adapter(named: "system") != nil)
    }

    /// It exposes the safe/reversible control hooks the prompt names.
    @Test func exposesExpectedHooks() {
        let system = SystemAppleScriptAdapter()
        for hook in [
            "toggle_dark_mode", "dark_mode_on", "dark_mode_off",
            "volume_up", "volume_down", "mute", "unmute", "lock_screen",
        ] {
            #expect(system.scripts[hook] != nil, "missing hook \(hook)")
        }
    }

    /// No irreversible hooks (e.g. emptying the Trash) — apple_script
    /// actions aren't confirm-gated, so destructive ones are excluded.
    @Test func excludesDestructiveHooks() {
        let keys = SystemAppleScriptAdapter().scripts.keys
        #expect(!keys.contains("empty_trash"))
    }
}
