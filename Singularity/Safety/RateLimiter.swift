//
//  RateLimiter.swift
//  Singularity
//

import Foundation

/// In-process sliding-window rate limiter for submitted commands
/// (brief §11.1). Defaults to 20/minute and 200/hour, which together
/// stop runaway re-prompt loops and paste-bomb denial-of-wallet without
/// any dependency.
///
/// `@MainActor` because it's consulted from the shell input path and
/// holds mutable state; the clock is injectable so the window slide can
/// be tested without real time passing.
@MainActor
final class RateLimiter {
    enum Decision: Equatable {
        case allowed
        case rateLimited
    }

    struct Limit: Equatable {
        let maxCount: Int
        let window: TimeInterval
    }

    private let limits: [Limit]
    private let now: () -> Date
    private var timestamps: [Date] = []

    init(
        limits: [Limit] = [Limit(maxCount: 20, window: 60), Limit(maxCount: 200, window: 3600)],
        now: @escaping () -> Date = { Date() }
    ) {
        self.limits = limits
        self.now = now
    }

    /// Records an attempt. Returns `.allowed` (and counts it) if every
    /// window is under its cap, otherwise `.rateLimited` (not counted).
    func record() -> Decision {
        let current = now()
        let widest = limits.map(\.window).max() ?? 0
        timestamps.removeAll { current.timeIntervalSince($0) >= widest }

        for limit in limits {
            let count = timestamps.filter { current.timeIntervalSince($0) < limit.window }.count
            if count >= limit.maxCount {
                return .rateLimited
            }
        }

        timestamps.append(current)
        return .allowed
    }
}
