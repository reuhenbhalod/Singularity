//
//  RoutineParser.swift
//  Singularity
//

import Foundation

/// Parses the inline `routine NAME = step1; step2` definition syntax
/// (US-RT-1). Names are validated and reserved words rejected so a
/// routine can never shadow a literal command (US-RT-6).
enum RoutineParser {
    /// Words a routine may not be named — they're literal commands.
    static let reservedWords: Set<String> = [
        "routine", "routines", "abort", "run", "delete",
        "cancel", "help", "settings", "quit", "exit",
    ]

    enum Result: Equatable {
        /// A valid definition. `overwrite` is the trailing confirm token.
        case definition(name: String, steps: [String], overwrite: Bool)
        case failure(message: String)
    }

    /// Parses text of the form `NAME = step1; step2` (the part AFTER the
    /// `routine` keyword). Name is lowercased for storage.
    ///
    /// `honorOverwriteToken` is true for inline creation (a trailing
    /// `overwrite` word confirms replacing an existing routine). The
    /// Settings edit path passes false: the user is already editing a
    /// specific routine, so a step that legitimately ends in the word
    /// "overwrite" must be preserved, not treated as a confirm token.
    static func parse(_ text: String, honorOverwriteToken: Bool = true) -> Result {
        guard let equals = text.firstIndex(of: "=") else {
            return .failure(message: "Missing '='. Try: routine NAME = step1; step2")
        }
        let name = text[..<equals].trimmingCharacters(in: .whitespaces)
        var stepsText = text[text.index(after: equals)...].trimmingCharacters(in: .whitespaces)

        guard isValidName(name) else {
            return .failure(
                message:
                    "'\(name)' isn't a valid routine name (start with a letter; letters, digits, _ or -; 1–32 chars).")
        }
        if reservedWords.contains(name.lowercased()) {
            return .failure(message: "'\(name)' is a reserved word — pick another name.")
        }

        // A trailing `overwrite` token confirms replacing an existing routine.
        var overwrite = false
        if honorOverwriteToken, stepsText.lowercased().hasSuffix(" overwrite") {
            overwrite = true
            stepsText = String(stepsText.dropLast(" overwrite".count)).trimmingCharacters(in: .whitespaces)
        }

        let steps = stepsText.split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !steps.isEmpty else {
            return .failure(message: "A routine needs at least one step.")
        }
        return .definition(name: name.lowercased(), steps: steps, overwrite: overwrite)
    }

    static func isValidName(_ name: String) -> Bool {
        name.range(of: "^[a-zA-Z][a-zA-Z0-9_-]{0,31}$", options: .regularExpression) != nil
    }
}
