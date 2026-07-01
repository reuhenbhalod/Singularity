//
//  ContentRing.swift
//  Singularity
//

import Foundation

/// A small ring buffer of recently-read untrusted content, used for the
/// cross-context contamination check (brief §11.6 / §11.3): if a later
/// plan tries to feed a chunk of freshly-read content into a shell
/// argument or URL, that's an indirect-injection attempt and the
/// validator rejects it.
///
/// The shell/file actions this ultimately guards arrive in Phase 6; this
/// is the shared buffer they check against.
final class ContentRing {
    private var recent: [String] = []
    private let capacity: Int
    /// Substrings shorter than this are too common to be meaningful.
    private let minMatchLength: Int

    init(capacity: Int = 8, minMatchLength: Int = 12) {
        self.capacity = capacity
        self.minMatchLength = minMatchLength
    }

    /// Remembers a piece of read content (normalized, lowercased).
    func record(_ content: String) {
        let normalized = content.lowercased()
        guard normalized.count >= minMatchLength else { return }
        recent.append(normalized)
        if recent.count > capacity {
            recent.removeFirst(recent.count - capacity)
        }
    }

    /// Whether `argument` contains a meaningful run of recently-read
    /// content — i.e. read-then-inject.
    func isTainted(_ argument: String) -> Bool {
        let candidate = argument.lowercased()
        for content in recent {
            for window in Self.windows(of: content, length: minMatchLength) where candidate.contains(window) {
                return true
            }
        }
        return false
    }

    /// Sliding windows of `length` over `text` (bounded so long content
    /// can't blow up the check).
    private static func windows(of text: String, length: Int) -> [String] {
        let chars = Array(text)
        guard chars.count >= length else { return [] }
        var out: [String] = []
        var index = 0
        while index + length <= chars.count {
            out.append(String(chars[index..<index + length]))
            index += max(1, length / 2)  // stride to keep the set small
        }
        return out
    }
}
