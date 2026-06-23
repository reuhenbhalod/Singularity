//
//  InputValidatorTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

/// Collects the lines the validator emits.
private final class WarnSink {
    private(set) var lines: [String] = []
    func warn(_ line: String) { lines.append(line) }
}

@MainActor
struct InputValidatorTests {
    /// Zero-width, bidi, and control characters are stripped; the
    /// visible text survives.
    @Test func stripsInvisibleAndControlCharacters() {
        let sink = WarnSink()
        let dirty = "play\u{200B} mr\u{202E}beast\u{0007} video"
        let outcome = InputValidator(warn: sink.warn).validate(dirty)

        guard case .submit(let clean) = outcome else {
            Issue.record("expected submit, got \(outcome)")
            return
        }
        #expect(clean == "play mrbeast video")
    }

    /// Newline and tab are preserved.
    @Test func keepsNewlineAndTab() {
        let sink = WarnSink()
        let outcome = InputValidator(warn: sink.warn).validate("a\nb\tc")
        #expect(outcome == .submit("a\nb\tc"))
    }

    /// T-P2-08: an AWS-key-shaped input is dropped with the exact
    /// guidance, and the raw key is never logged.
    @Test func dropsAWSKeyWithoutLoggingIt() {
        let sink = WarnSink()
        let outcome = InputValidator(warn: sink.warn).validate("my key AKIAIOSFODNN7EXAMPLE please")

        #expect(outcome == .blocked)
        #expect(
            sink.lines.contains(
                "I dropped that — it contained what looked like an AWS key. Retype without the key."
            )
        )
        #expect(!sink.lines.contains { $0.contains("AKIAIOSFODNN7EXAMPLE") })
    }

    /// T-P2-08: a password-shaped token warns but still submits.
    @Test func passwordWarnsButSubmits() {
        let sink = WarnSink()
        let outcome = InputValidator(warn: sink.warn).validate("login with Xy7$kLp2qWmz now")

        guard case .submit = outcome else {
            Issue.record("expected submit (warn-only), got \(outcome)")
            return
        }
        #expect(sink.lines.contains { $0.lowercased().contains("password") })
    }

    /// T-P2-08: over-cap input truncates to 4 KB with a log line.
    @Test func overCapTruncatesWithMessage() {
        let sink = WarnSink()
        let outcome = InputValidator(warn: sink.warn).validate(String(repeating: "a", count: 5000))

        guard case .submit(let clean) = outcome else {
            Issue.record("expected submit, got \(outcome)")
            return
        }
        #expect(clean.count == InputValidator.maxInputLength)
        #expect(sink.lines.contains(InputValidator.truncationMessage))
    }

    /// Exceeding the rate limit blocks with guidance.
    @Test func rateLimitBlocks() {
        let sink = WarnSink()
        let limiter = RateLimiter(limits: [RateLimiter.Limit(maxCount: 1, window: 60)])
        let validator = InputValidator(warn: sink.warn, rateLimiter: limiter)

        #expect(validator.validate("hello") == .submit("hello"))
        #expect(validator.validate("again") == .blocked)
        #expect(sink.lines.contains { $0.contains("Too many commands") })
    }
}
