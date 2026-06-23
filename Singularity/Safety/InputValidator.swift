//
//  InputValidator.swift
//  Singularity
//

import Foundation

/// The single boundary every typed command crosses before it reaches
/// the planner (brief §11.1). Deterministic pipeline:
/// `normalize → cap → scan → rate-limit → submit`.
///
/// - Normalization and the length cap are silent transforms (a cap also
///   emits one log line).
/// - The credential scan is the only hard block, and only for
///   high-confidence categories; the raw input is never logged.
/// - The password heuristic is warn-only.
///
/// Logging goes through an injected `warn` closure so this stays
/// decoupled from the Shell's `SessionLogStore`.
@MainActor
struct InputValidator {
    enum Outcome: Equatable {
        /// Cleaned, safe text to hand to the planner.
        case submit(String)
        /// Refused; an explanatory line was already emitted via `warn`.
        case blocked
    }

    static let maxInputLength = 4096
    static let truncationMessage = "input truncated to 4 KB"

    private let warn: (String) -> Void
    private let rateLimiter: RateLimiter

    init(warn: @escaping (String) -> Void, rateLimiter: RateLimiter? = nil) {
        self.warn = warn
        // Constructed here, not as a default argument: RateLimiter's init
        // is @MainActor-isolated.
        self.rateLimiter = rateLimiter ?? RateLimiter()
    }

    func validate(_ rawInput: String) -> Outcome {
        var text = Self.normalize(rawInput)

        if text.count > Self.maxInputLength {
            text = String(text.prefix(Self.maxInputLength))
            warn(Self.truncationMessage)
        }

        // Fail-closed on high-confidence secrets; never log the raw text.
        if let category = SecretPatterns.firstMatch(in: text) {
            warn(
                "I dropped that — it contained what looked like \(category.phrase). "
                    + "Retype without the key."
            )
            return .blocked
        }

        if SecretPatterns.looksLikePassword(text) {
            warn("Heads up: that looked like it might contain a password.")
        }

        if rateLimiter.record() == .rateLimited {
            warn("Too many commands too fast — give it a moment and try again.")
            return .blocked
        }

        return .submit(text)
    }

    /// Strips invisible/injection-vector characters and applies NFC.
    /// Removes zero-width characters, bidi controls, and C0/C1 control
    /// characters except newline and tab. Reused for untrusted fetched
    /// content in Phase 5 (brief §11.6).
    static func normalize(_ input: String) -> String {
        let kept = input.unicodeScalars.filter { scalar in
            let value = scalar.value
            if (0x200B...0x200F).contains(value) { return false }  // zero-width
            if value == 0xFEFF { return false }  // ZWNBSP / BOM
            if (0x202A...0x202E).contains(value) { return false }  // bidi embeddings
            if (0x2066...0x2069).contains(value) { return false }  // bidi isolates
            if scalar.properties.generalCategory == .control, value != 0x0A, value != 0x09 {
                return false  // C0/C1 controls except \n, \t
            }
            return true
        }
        return String(String.UnicodeScalarView(kept)).precomposedStringWithCanonicalMapping
    }
}
