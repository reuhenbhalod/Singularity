//
//  SecretPatterns.swift
//  Singularity
//

import Foundation

/// A small in-process bank of high-confidence secret shapes, scanned at
/// the input boundary before anything reaches the planner (brief §11.1).
///
/// The regex categories are fail-closed: a match means the input is
/// refused and the raw text is never logged. `looksLikePassword` is a
/// separate warn-only heuristic (false positives are inevitable, so it
/// never blocks).
enum SecretPatterns {
    /// A category of high-confidence secret. `phrase` is the
    /// user-facing description ("an AWS key").
    enum Category: Equatable, Sendable {
        case awsAccessKey
        case githubToken
        case openAIKey
        case slackToken
        case stripeKey
        case googleAPIKey
        case creditCard
        case ssn

        var phrase: String {
            switch self {
            case .awsAccessKey: return "an AWS key"
            case .githubToken: return "a GitHub token"
            case .openAIKey: return "an OpenAI key"
            case .slackToken: return "a Slack token"
            case .stripeKey: return "a Stripe key"
            case .googleAPIKey: return "a Google API key"
            case .creditCard: return "a credit card number"
            case .ssn: return "a Social Security number"
            }
        }
    }

    /// The first high-confidence secret found in `text`, or `nil`.
    static func firstMatch(in text: String) -> Category? {
        for (category, pattern) in regexCategories
        where text.range(of: pattern, options: .regularExpression) != nil {
            return category
        }
        if containsLuhnValidCard(text) {
            return .creditCard
        }
        return nil
    }

    /// Warn-only: a standalone token 10–64 chars long mixing upper,
    /// lower, digit, and symbol — the shape of a pasted password. Never
    /// used to block.
    static func looksLikePassword(_ text: String) -> Bool {
        for token in text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            guard (10...64).contains(token.count) else { continue }
            let hasUpper = token.contains { $0.isUppercase }
            let hasLower = token.contains { $0.isLowercase }
            let hasDigit = token.contains { $0.isNumber }
            let hasSymbol = token.contains { !$0.isLetter && !$0.isNumber }
            if hasUpper && hasLower && hasDigit && hasSymbol {
                return true
            }
        }
        return false
    }

    // MARK: - Patterns

    /// Regex categories, checked in order. Credit cards are handled
    /// separately because they need a Luhn check to cut false positives.
    private static let regexCategories: [(Category, String)] = [
        (.awsAccessKey, "AKIA[0-9A-Z]{16}"),
        (.githubToken, "gh[pousr]_[A-Za-z0-9]{36,}"),
        (.openAIKey, "sk-(proj-|svcacct-|admin-)?[A-Za-z0-9]{32,}"),
        (.slackToken, "xox[baprs]-[A-Za-z0-9-]{10,}"),
        (.stripeKey, "(sk|pk|rk)_live_[A-Za-z0-9]{16,}"),
        (.googleAPIKey, "AIza[0-9A-Za-z_-]{35}"),
        (.ssn, "\\b\\d{3}-\\d{2}-\\d{4}\\b"),
    ]

    /// True if `text` contains a 13–19 digit run that passes the Luhn
    /// checksum (a real card number, not just any long number).
    private static func containsLuhnValidCard(_ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "\\b\\d{13,19}\\b") else {
            return false
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.contains { luhnValid(nsText.substring(with: $0.range)) }
    }

    private static func luhnValid(_ number: String) -> Bool {
        let digits = number.compactMap(\.wholeNumberValue)
        guard digits.count >= 13 else { return false }
        var sum = 0
        for (index, digit) in digits.reversed().enumerated() {
            if index.isMultiple(of: 2) {
                sum += digit
            } else {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum.isMultiple(of: 10)
    }
}
