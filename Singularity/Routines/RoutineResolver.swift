//
//  RoutineResolver.swift
//  Singularity
//

import Foundation

/// Decides whether a raw command invokes a routine, and to which steps it
/// expands (US-RT-2 / US-RT-6). Only two forms trigger expansion — the
/// bare name (`dev`) or `run NAME` — so a routine never silently takes
/// over a natural-language sentence that merely contains its name.
struct RoutineResolver {
    enum Resolution: Equatable {
        /// A routine was invoked; run these steps in order.
        case expanded(name: String, steps: [String])
        /// `run NAME` for a routine that doesn't exist.
        case notFound(name: String)
        /// Not a routine — hand to the planner as usual.
        case passthrough
    }

    /// name (lowercased) → steps.
    private let routines: [String: [String]]

    init(routines: [String: [String]]) {
        self.routines = routines
    }

    func resolve(_ input: String) -> Resolution {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Explicit: `run NAME`
        if trimmed.lowercased().hasPrefix("run ") {
            let name = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces).lowercased()
            if let steps = routines[name] {
                return .expanded(name: name, steps: steps)
            }
            return .notFound(name: name)
        }

        // Bare name: the ENTIRE trimmed input, with no internal whitespace,
        // matching a routine (case-insensitive). Anything with a space
        // falls through to the planner.
        if !trimmed.contains(where: \.isWhitespace),
            let steps = routines[trimmed.lowercased()]
        {
            return .expanded(name: trimmed.lowercased(), steps: steps)
        }

        return .passthrough
    }
}
