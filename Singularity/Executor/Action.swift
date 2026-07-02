//
//  Action.swift
//  Singularity
//

import Foundation

/// One concrete thing the executor can do. Each case corresponds to
/// one lane of the executor waterfall (research brief §4 architecture
/// diagram). Phase 1 only uses `.openURL` and `.webEvaluate`; later
/// phases add cases for the Accessibility, AppleScript, and Files
/// lanes.
///
/// `Codable` so plans can round-trip through JSON. The on-wire shape
/// is `{"kind": "open_url", "url": "..."}` (snake_case discriminator
/// + per-kind payload fields) — designed to match the strict JSON
/// schema the Ollama planner emits in Phase 2.
enum Action: Equatable {
    /// Lane 1: hand the URL to `NSWorkspace.open(_:)` so the system's
    /// URL handler (`https`, `spotify:`, `vscode:`, etc.) launches it.
    case openURL(URL)

    /// Lane 2: navigate the active `WKWebView` pane to the URL.
    /// Router creates a new pane if none exists.
    case webNavigate(URL)

    /// Lane 2: evaluate JavaScript in the active `WKWebView` pane.
    case webEvaluate(script: String)

    /// Lane 2: run a named hook from a named `WebAdapter` against
    /// the active pane (e.g. `adapter: "youtube"`, `hook:
    /// "play_newest"`). The adapter owns the resilient selectors;
    /// the planner only names what to run.
    case runScript(adapter: String, hook: String)

    /// Lane 3 (Accessibility): run a named hook from a named
    /// `AXAdapter` against a native app (e.g. `adapter: "spotify"`,
    /// `hook: "playpause"`). Like `runScript`, the adapter owns the AX
    /// traversal; the planner only names the app and the operation.
    case axAction(adapter: String, hook: String)

    /// Lane 4 (AppleScript): run a named hook from a named
    /// `AppleScriptAdapter` against an Apple-native app (e.g.
    /// `adapter: "music"`, `hook: "playpause"`). The adapter owns the
    /// compiled scripts; the planner only names the app and operation.
    case appleScript(adapter: String, hook: String)

    /// Lane 5 (Files): a file operation. `operation` is one of
    /// `move`/`copy`/`list`/`trash`; `source` is the target path;
    /// `destination` is the move/copy target (nil for list/trash).
    /// Deletes always use the Trash (never `unlink`), and every path is
    /// re-validated by `FilePathValidator` before it runs.
    case fileOp(operation: String, source: String, destination: String?)

    /// Lane 5 (Shell): a sandboxed shell command run inside `scope`
    /// (the declared working directory). Passes the `ShellValidator`
    /// static rules and runs under `sandbox-exec`.
    case runShell(command: String, scope: String)
}

extension Action: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case url
        case script
        case adapter
        case hook
        case operation
        case source
        case destination
        case command
        case scope
    }

    private enum Kind: String, Codable {
        case openURL = "open_url"
        case webNavigate = "web_navigate"
        case webEvaluate = "web_evaluate"
        case runScript = "run_script"
        case axAction = "ax_action"
        case appleScript = "apple_script"
        case fileOp = "file_op"
        case runShell = "run_shell"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .openURL:
            self = .openURL(try container.decode(URL.self, forKey: .url))
        case .webNavigate:
            self = .webNavigate(try container.decode(URL.self, forKey: .url))
        case .webEvaluate:
            self = .webEvaluate(script: try container.decode(String.self, forKey: .script))
        case .runScript:
            self = .runScript(
                adapter: try container.decode(String.self, forKey: .adapter),
                hook: try container.decode(String.self, forKey: .hook)
            )
        case .axAction:
            self = .axAction(
                adapter: try container.decode(String.self, forKey: .adapter),
                hook: try container.decode(String.self, forKey: .hook)
            )
        case .appleScript:
            self = .appleScript(
                adapter: try container.decode(String.self, forKey: .adapter),
                hook: try container.decode(String.self, forKey: .hook)
            )
        case .fileOp:
            self = .fileOp(
                operation: try container.decode(String.self, forKey: .operation),
                source: try container.decode(String.self, forKey: .source),
                destination: try container.decodeIfPresent(String.self, forKey: .destination)
            )
        case .runShell:
            self = .runShell(
                command: try container.decode(String.self, forKey: .command),
                scope: try container.decode(String.self, forKey: .scope)
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .openURL(let url):
            try container.encode(Kind.openURL, forKey: .kind)
            try container.encode(url, forKey: .url)
        case .webNavigate(let url):
            try container.encode(Kind.webNavigate, forKey: .kind)
            try container.encode(url, forKey: .url)
        case .webEvaluate(let script):
            try container.encode(Kind.webEvaluate, forKey: .kind)
            try container.encode(script, forKey: .script)
        case .runScript(let adapter, let hook):
            try container.encode(Kind.runScript, forKey: .kind)
            try container.encode(adapter, forKey: .adapter)
            try container.encode(hook, forKey: .hook)
        case .axAction(let adapter, let hook):
            try container.encode(Kind.axAction, forKey: .kind)
            try container.encode(adapter, forKey: .adapter)
            try container.encode(hook, forKey: .hook)
        case .appleScript(let adapter, let hook):
            try container.encode(Kind.appleScript, forKey: .kind)
            try container.encode(adapter, forKey: .adapter)
            try container.encode(hook, forKey: .hook)
        case .fileOp(let operation, let source, let destination):
            try container.encode(Kind.fileOp, forKey: .kind)
            try container.encode(operation, forKey: .operation)
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(destination, forKey: .destination)
        case .runShell(let command, let scope):
            try container.encode(Kind.runShell, forKey: .kind)
            try container.encode(command, forKey: .command)
            try container.encode(scope, forKey: .scope)
        }
    }
}
