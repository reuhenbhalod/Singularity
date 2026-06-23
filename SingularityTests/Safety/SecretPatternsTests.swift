//
//  SecretPatternsTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct SecretPatternsTests {
    /// One positive per category; each must be detected.
    @Test(arguments: [
        (SecretPatterns.Category.awsAccessKey, "creds AKIAIOSFODNN7EXAMPLE here"),
        (.githubToken, "token ghp_0123456789abcdefghijklmnopqrstuvwxyzAB"),
        (.openAIKey, "key sk-proj-0123456789abcdefghijklmNOPQRSTUVWX1234"),
        (.slackToken, "xoxb-123456789012-abcdefABCDEF"),
        (.stripeKey, "use sk_live_0123456789abcdefABCDEF"),
        (.googleAPIKey, "AIzaSyA0123456789abcdefghijklmnopqrstuv"),
        (.creditCard, "card 4242424242424242 ok"),
        (.ssn, "ssn 123-45-6789 ok"),
    ])
    func detectsPositive(category: SecretPatterns.Category, input: String) {
        #expect(SecretPatterns.firstMatch(in: input) == category)
    }

    /// Near-misses across categories: none should match any secret.
    @Test(arguments: [
        // AWS
        "AKIA123", "akiaiosfodnn7example", "my aws account id",
        // GitHub
        "ghp_short", "just a github token", "gho_12345",
        // OpenAI
        "sk-test", "ski jump lesson", "ask-me-anything",
        // Slack
        "xox-", "box-1234567890", "xoxo gossip",
        // Stripe
        "sk_test_abc123", "pk_live_short", "stripe checkout",
        // Google
        "AIzaShort", "Arizona is hot", "AIza-only",
        // Credit card (Luhn-failing / too short)
        "4242424242424240", "phone 5551234567", "order 12345",
        // SSN (wrong shape)
        "123456789", "12-345-6789", "call 123-456-7890",
    ])
    func ignoresNearMiss(input: String) {
        #expect(SecretPatterns.firstMatch(in: input) == nil, "false positive on '\(input)'")
    }

    /// Password-shaped tokens warn; ordinary prose does not.
    @Test func passwordHeuristic() {
        #expect(SecretPatterns.looksLikePassword("my password is Xy7$kLp2qWmz"))
        #expect(!SecretPatterns.looksLikePassword("just a normal sentence with words"))
        #expect(!SecretPatterns.looksLikePassword("short A1$"))
    }

    /// A Luhn-valid card with a different BIN is still caught; a
    /// Luhn-invalid 16-digit number is not.
    @Test func luhnGatesCreditCards() {
        #expect(SecretPatterns.firstMatch(in: "5555555555554444") == .creditCard)  // Luhn-valid
        #expect(SecretPatterns.firstMatch(in: "5555555555554445") == nil)  // Luhn-invalid
    }
}
