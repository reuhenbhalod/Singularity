//
//  UntrustedContentFilter.swift
//  Singularity
//

import Foundation

/// Content that has been wrapped in an untrusted-content envelope. Its
/// initializer is `fileprivate`, so `UntrustedContentFilter` (below, same
/// file) is the ONLY thing that can produce one — the type-level rule
/// that anything read from the web / AX / mail / files must be wrapped
/// before it can reach a planner prompt (brief §11.6 / US-SAFE-6). A bare
/// `String` can never be appended to planner context; only an
/// `EnvelopedContent` can.
struct EnvelopedContent: Equatable {
    let envelope: String

    fileprivate init(envelope: String) {
        self.envelope = envelope
    }
}

/// Wraps and screens untrusted content. Everything the shell *reads*
/// (page text, an AX value, an email body, a file) passes through
/// `wrap(...)` before it can enter the model context: content inside the
/// envelope is data, never instructions.
enum UntrustedContentFilter {
    /// Wraps `content` from `source` in an `<UNTRUSTED-CONTENT>` envelope,
    /// after normalizing unicode and neutralizing any literal envelope
    /// tags smuggled inside the content.
    static func wrap(content: String, source: String, id: String = UUID().uuidString)
        -> EnvelopedContent
    {
        let normalized = InputValidator.normalize(content)
        let neutralized =
            normalized
            .replacingOccurrences(of: "<UNTRUSTED-CONTENT", with: "&lt;UNTRUSTED-CONTENT")
            .replacingOccurrences(of: "</UNTRUSTED-CONTENT", with: "&lt;/UNTRUSTED-CONTENT")
        let envelope =
            "<UNTRUSTED-CONTENT source=\"\(source)\" id=\"\(id)\">\(neutralized)</UNTRUSTED-CONTENT>"
        return EnvelopedContent(envelope: envelope)
    }

    /// Injection-detection heuristic: does `content` try to talk to the
    /// model as if it were an instruction? A hit doesn't hard-refuse — it
    /// raises a warning and the caller escalates the next plan's risk one
    /// level harsher (US-SAFE-6, §6 decision #4).
    static func looksLikeInjection(_ content: String) -> Bool {
        let lowered = content.lowercased()
        return injectionMarkers.contains { lowered.contains($0) }
    }

    private static let injectionMarkers = [
        "ignore previous instructions",
        "ignore all previous",
        "disregard the above",
        "you are now",
        "system:",
        "assistant:",
        "new instructions:",
    ]
}
