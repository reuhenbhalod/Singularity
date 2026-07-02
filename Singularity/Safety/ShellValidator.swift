//
//  ShellValidator.swift
//  Singularity
//

import Foundation

/// Static analysis of a shell command before it can run (brief §11.3 /
/// T-P6-08). Rejects the classic escape-hatch patterns — pipe-to-shell,
/// base64-to-shell, `eval`, `sudo`, `..` traversal, and access to
/// TCC-protected paths — before the sandbox ever sees it. Fail-closed:
/// the first matching rule rejects.
struct ShellValidator {
    enum Outcome: Equatable {
        case ok
        case rejected(rule: String)
    }

    func validate(_ command: String) -> Outcome {
        let matches: (String) -> Bool = { pattern in
            command.range(of: pattern, options: .regularExpression) != nil
        }

        if matches(#"(curl|wget)\b[^|]*\|\s*(sh|bash|zsh)"#) {
            return .rejected(rule: "pipe-to-shell")
        }
        if matches(#"base64\b[^|]*\|\s*(sh|bash|zsh)"#) {
            return .rejected(rule: "base64-to-shell")
        }
        if matches(#"\beval\b"#) {
            return .rejected(rule: "eval")
        }
        if matches(#"\bsudo\b"#) {
            return .rejected(rule: "sudo")
        }
        if command.contains("..") {
            return .rejected(rule: "path-escape")
        }
        for protectedPath in ["~/Library", "/Library/Keychains", "/System", ".ssh", ".aws"]
        where command.contains(protectedPath) {
            return .rejected(rule: "protected-path")
        }
        return .ok
    }
}
