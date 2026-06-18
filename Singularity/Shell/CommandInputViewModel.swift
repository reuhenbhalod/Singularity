//
//  CommandInputViewModel.swift
//  Singularity
//

import Foundation
import Observation

/// State and behavior for the shell's command input.
///
/// Owns the input text and the 4 KB cap from research brief §11.1 /
/// spec US-S-2. Side effects (submit, dismiss, push line to log) are
/// exposed as closures so the SwiftUI view stays presentation-only
/// and `ShellWindowController` can wire concrete actions to them.
@MainActor
@Observable
final class CommandInputViewModel {
    /// Hard cap on raw input (= 4 KB per brief §11.1).
    static let maxInputLength = 4096

    /// Truncation log line emitted when input exceeds `maxInputLength`.
    static let truncationLogLine = "input truncated to 4 KB"

    var text: String = ""

    /// Called when the user presses Return on non-empty input.
    /// Argument is the submitted text.
    var onSubmit: (String) -> Void = { _ in }

    /// Called when the user presses Esc on EMPTY input.
    /// (Esc on non-empty input clears the text and does not dismiss.)
    var onDismiss: () -> Void = {}

    /// Called when the input pushes a system line into the session log
    /// (currently only the truncation warning; later tasks will add more).
    var onLog: (String) -> Void = { _ in }

    /// Set the input text, enforcing the cap. If the supplied value is
    /// longer than `maxInputLength`, it is truncated and a single
    /// truncation log line is emitted.
    func setText(_ newValue: String) {
        if newValue.count > Self.maxInputLength {
            text = String(newValue.prefix(Self.maxInputLength))
            onLog(Self.truncationLogLine)
        } else {
            text = newValue
        }
    }

    /// Return pressed. No-op on empty input; otherwise calls `onSubmit`
    /// with the current text, then clears the field.
    func submit() {
        guard !text.isEmpty else { return }
        let snapshot = text
        text = ""
        onSubmit(snapshot)
    }

    /// Esc pressed. Empty input -> `onDismiss`; non-empty -> clear the
    /// text without dismissing.
    func escape() {
        if text.isEmpty {
            onDismiss()
        } else {
            text = ""
        }
    }
}
