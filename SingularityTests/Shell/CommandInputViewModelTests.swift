//
//  CommandInputViewModelTests.swift
//  SingularityTests
//

import Testing

@testable import Singularity

@MainActor
struct CommandInputViewModelTests {
    /// T-P0-08 acceptance: typing 4097 characters truncates to 4096.
    @Test func setTextRespectsFourKBCap() {
        let viewModel = CommandInputViewModel()
        viewModel.setText(String(repeating: "x", count: 4097))
        #expect(viewModel.text.count == 4096)
    }

    /// T-P0-08 acceptance: truncation emits one "input truncated to 4 KB"
    /// log line.
    @Test func setTextOverCapEmitsOneTruncationLogLine() {
        let viewModel = CommandInputViewModel()
        var logged: [String] = []
        viewModel.onLog = { logged.append($0) }

        viewModel.setText(String(repeating: "x", count: 4097))

        #expect(logged == [CommandInputViewModel.truncationLogLine])
    }

    /// Under-cap input does not emit a truncation log.
    @Test func setTextUnderCapDoesNotEmitLog() {
        let viewModel = CommandInputViewModel()
        var logged: [String] = []
        viewModel.onLog = { logged.append($0) }

        viewModel.setText("hello world")

        #expect(logged.isEmpty)
        #expect(viewModel.text == "hello world")
    }

    /// T-P0-08 acceptance: Return submits and clears the input.
    @Test func submitCallsOnSubmitAndClearsText() {
        let viewModel = CommandInputViewModel()
        var submitted: [String] = []
        viewModel.onSubmit = { submitted.append($0) }
        viewModel.text = "play mrbeast newest video"

        viewModel.submit()

        #expect(submitted == ["play mrbeast newest video"])
        #expect(viewModel.text == "")
    }

    /// Return with empty input is a no-op.
    @Test func submitOnEmptyInputIsNoop() {
        let viewModel = CommandInputViewModel()
        var submitted: [String] = []
        viewModel.onSubmit = { submitted.append($0) }

        viewModel.submit()

        #expect(submitted.isEmpty)
    }

    /// T-P0-08 acceptance: Esc with empty input dismisses the shell.
    @Test func escapeOnEmptyInputDismisses() {
        let viewModel = CommandInputViewModel()
        var dismissCount = 0
        viewModel.onDismiss = { dismissCount += 1 }

        viewModel.escape()

        #expect(dismissCount == 1)
    }

    /// T-P0-08 acceptance: Esc with non-empty input clears the text and
    /// does NOT dismiss.
    @Test func escapeOnNonEmptyInputClearsTextWithoutDismissing() {
        let viewModel = CommandInputViewModel()
        var dismissCount = 0
        viewModel.onDismiss = { dismissCount += 1 }
        viewModel.text = "half-typed command"

        viewModel.escape()

        #expect(viewModel.text == "")
        #expect(dismissCount == 0)
    }

    /// Exactly-at-cap input is not truncated.
    @Test func setTextAtExactCapDoesNotTruncate() {
        let viewModel = CommandInputViewModel()
        var logged: [String] = []
        viewModel.onLog = { logged.append($0) }

        viewModel.setText(String(repeating: "x", count: 4096))

        #expect(viewModel.text.count == 4096)
        #expect(logged.isEmpty)
    }
}
