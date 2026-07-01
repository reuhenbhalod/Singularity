//
//  NSFWBlocklistTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct NSFWBlocklistTests {
    /// Parsing ignores blanks and comments, lowercases hosts.
    @Test func parseIgnoresCommentsAndBlanks() {
        let hosts = NSFWBlocklist.parse(
            """
            # a comment
            Example-Adult.com

            other.com
            """)
        #expect(hosts == ["example-adult.com", "other.com"])
    }

    /// Matching is subdomain-aware.
    @Test func matchesHostAndSubdomains() {
        let list = NSFWBlocklist(hosts: ["pornhub.com"])
        #expect(list.contains("pornhub.com"))
        #expect(list.contains("www.pornhub.com"))
        #expect(list.contains("cdn.media.pornhub.com"))
        #expect(!list.contains("pornhubby.com"))
        #expect(!list.contains("youtube.com"))
    }

    /// T-P5-08: an NSFW host is denied ahead of the allowlist; with the
    /// filter off the same host is denied by the allowlist anyway (off
    /// never widens access).
    @Test func urlPolicyBlocksNSFWAheadOfAllowlist() throws {
        let nsfw = NSFWBlocklist(hosts: ["pornhub.com"])
        let url = try #require(URL(string: "https://www.pornhub.com/"))

        let on = URLPolicy(nsfw: nsfw, nsfwEnabled: true)
        #expect(on.evaluate(url: url) == .deny(reason: .nsfwBlocked))

        let off = URLPolicy(nsfw: nsfw, nsfwEnabled: false)
        // Not on any adapter allowlist, so still denied — just for a
        // different reason. Turning NSFW off widened nothing.
        #expect(off.evaluate(url: url) == .deny(reason: .hostNotAllowed))
    }
}
