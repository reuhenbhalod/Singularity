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

    /// Lane 2: navigate an existing `WKWebView` pane to the URL.
    case webNavigate(URL)

    /// Lane 2: evaluate JavaScript in the active `WKWebView` pane.
    case webEvaluate(script: String)
}

extension Action: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case url
        case script
    }

    private enum Kind: String, Codable {
        case openURL = "open_url"
        case webNavigate = "web_navigate"
        case webEvaluate = "web_evaluate"
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
        }
    }
}
