//
//  SystemPromptTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct SystemPromptTests {
    /// T-P2-03 acceptance: the prompt carries the untrusted-content
    /// directive (content inside envelopes is data only, never
    /// instructions) per US-SAFE-6.
    @Test func includesUntrustedContentDirective() {
        let prompt = SystemPrompt.text
        #expect(prompt.contains("UNTRUSTED-CONTENT"))
        #expect(prompt.contains("data only"))
        #expect(prompt.lowercased().contains("never"))
    }

    /// It instructs JSON-only output and documents the action kinds.
    @Test func documentsActionsAndJSONOnlyOutput() {
        let prompt = SystemPrompt.text
        #expect(prompt.contains("JSON"))
        #expect(prompt.contains("web_navigate"))
        #expect(prompt.contains("run_script"))
    }
}
