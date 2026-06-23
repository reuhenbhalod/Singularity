//
//  RateLimiterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// A controllable clock so window slides can be tested instantly.
private final class TestClock {
    var date = Date(timeIntervalSince1970: 0)
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

@MainActor
struct RateLimiterTests {
    /// T-P2-07: 20 calls/minute succeed, the 21st is limited, and once
    /// the minute window slides, calls succeed again.
    @Test func minuteBucketBlocksThenRecovers() {
        let clock = TestClock()
        let limiter = RateLimiter(now: { clock.date })

        for index in 1...20 {
            #expect(limiter.record() == .allowed, "call \(index) should be allowed")
        }
        #expect(limiter.record() == .rateLimited)

        clock.advance(61)  // slide past the 60s window
        #expect(limiter.record() == .allowed)
    }

    /// T-P2-07: the hourly bucket caps at 200 (spacing calls 4s apart so
    /// the per-minute bucket never trips first).
    @Test func hourBucketBlocksAfter200() {
        let clock = TestClock()
        let limiter = RateLimiter(now: { clock.date })

        for index in 1...200 {
            #expect(limiter.record() == .allowed, "call \(index) should be allowed")
            clock.advance(4)  // 15/min steady state, under the 20/min cap
        }
        #expect(limiter.record() == .rateLimited)  // 201st within the hour
    }

    /// The hourly bucket also recovers once its window slides.
    @Test func hourBucketRecovers() {
        let clock = TestClock()
        let limiter = RateLimiter(now: { clock.date })

        for _ in 1...200 {
            _ = limiter.record()
            clock.advance(4)
        }
        #expect(limiter.record() == .rateLimited)

        clock.advance(3600)  // slide past the hour
        #expect(limiter.record() == .allowed)
    }
}
