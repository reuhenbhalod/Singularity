//
//  Latency.swift
//  Singularity
//

import os

/// Lightweight latency instrumentation (T-P7-23). Wraps the three
/// performance-sensitive paths — hotkey-to-focus, command Return-to-result,
/// and Settings-open — in os_signpost intervals (visible in Instruments'
/// "Points of Interest") and emits an elapsed-ms line to the `latency`
/// OSLog category so the numbers are observable in Console without a
/// profiler attached.
enum Latency {
    static let subsystem = "com.reuhenbhalod.Singularity"
    private static let logger = Logger(subsystem: subsystem, category: "latency")
    private static let signposter = OSSignposter(subsystem: subsystem, category: "latency")

    /// Times a synchronous block, logs its duration, and records a signpost
    /// interval. Returns the block's value.
    @discardableResult
    static func measure<T>(_ name: StaticString, _ body: () -> T) -> T {
        let state = signposter.beginInterval(name)
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            signposter.endInterval(name, state)
            logger.info("\(name, privacy: .public): \(ms, privacy: .public) ms")
        }
        return body()
    }

    /// Times an async block (e.g. a full command run through the pipeline).
    @discardableResult
    static func measureAsync<T>(_ name: StaticString, _ body: () async -> T) async -> T {
        let state = signposter.beginInterval(name)
        let start = DispatchTime.now().uptimeNanoseconds
        let result = await body()
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        signposter.endInterval(name, state)
        logger.info("\(name, privacy: .public): \(ms, privacy: .public) ms")
        return result
    }

    /// Logs elapsed ms since a captured start — for inline instrumentation
    /// where wrapping in a closure would be awkward (e.g. `show()`).
    static func logElapsed(_ name: StaticString, since start: DispatchTime) {
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        logger.info("\(name, privacy: .public): \(ms, privacy: .public) ms")
    }

    /// Elapsed milliseconds of a synchronous block, without logging — for
    /// tests that assert a budget.
    static func elapsedMs(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}
