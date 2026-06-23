//
//  URLPolicyTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct URLPolicyTests {
    private let policy = URLPolicy()

    private func evaluate(_ string: String) throws -> URLPolicy.Decision {
        policy.evaluate(url: try #require(URL(string: string)))
    }

    /// T-P3-06: an on-list HTTPS URL is allowed.
    @Test func allowsOnListHTTPS() throws {
        #expect(try evaluate("https://www.youtube.com/@MrBeast/videos") == .allow)
    }

    /// T-P3-06: an off-list HTTPS host is denied.
    @Test func deniesOffListHTTPS() throws {
        #expect(try evaluate("https://example.com/") == .deny(reason: .hostNotAllowed))
    }

    /// T-P3-06: HTTP is denied even for an allowed host.
    @Test func deniesHTTP() throws {
        #expect(try evaluate("http://www.youtube.com/") == .deny(reason: .notHTTPS))
    }

    /// T-P3-06: userinfo is denied even for an allowed host.
    @Test func deniesUserInfo() throws {
        #expect(try evaluate("https://user:pass@www.youtube.com/") == .deny(reason: .userInfoPresent))
    }

    /// T-P3-06: non-HTTPS schemes (data/file/javascript) are denied.
    @Test func deniesDangerousSchemes() throws {
        #expect(try evaluate("data:text/html,hi") == .deny(reason: .notHTTPS))
        #expect(try evaluate("file:///etc/passwd") == .deny(reason: .notHTTPS))
        #expect(try evaluate("javascript:alert(1)") == .deny(reason: .notHTTPS))
    }
}
