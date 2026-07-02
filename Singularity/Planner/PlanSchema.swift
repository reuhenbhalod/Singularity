//
//  PlanSchema.swift
//  Singularity
//

import Foundation

/// The JSON Schema that constrains the planner's output to a `RawPlan`
/// shape — `{ "steps": [ { "action": { "kind": ..., ... } } ] }` —
/// matching `RawPlan` / `PlanStep` / `Action`'s `Codable` form.
///
/// Passed to Ollama as `format: .schema(...)` so generation is
/// grammar-constrained token-by-token (research brief §1). Kept flat
/// rather than recursive, since deeply nested schemas are flaky under
/// constrained decoding. The same schema lives as a static asset at
/// `Resources/plan-schema.json` for tooling.
enum PlanSchema {
    static let json: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "steps": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "action": action,
                        // Optional: open this navigation in a new pane
                        // instead of reusing the current one. Only the
                        // planner sets it (and only when the user asks);
                        // absent means reuse.
                        "new_pane": .object(["type": .string("boolean")]),
                    ]),
                    "required": .array([.string("action")]),
                ]),
            ])
        ]),
        "required": .array([.string("steps")]),
    ])

    /// The schema wrapped for Ollama's `format` parameter.
    static var ollamaFormat: OllamaFormat { .schema(json) }

    /// A discriminated union: one variant per action kind, each
    /// *requiring* exactly the fields that kind needs. This is what
    /// forces the grammar-constrained model to emit `hook` for
    /// `run_script` (etc.) — a flat schema marking only `kind` required
    /// lets the model drop per-kind fields, which then fail to decode.
    ///
    /// `web_evaluate` is deliberately omitted: grammar-constrained
    /// decoding means the model literally cannot emit it, so it can't
    /// improvise raw DOM-scraping JavaScript (unreliable and a security
    /// hole). The planner must drive pages through named adapter hooks
    /// (`run_script`). `Action.webEvaluate` still exists for the
    /// executor; it just isn't part of the planner's output vocabulary.
    private static let action: JSONValue = .object([
        "oneOf": .array([
            variant(kind: "open_url", fields: ["url"]),
            variant(kind: "web_navigate", fields: ["url"]),
            variant(kind: "run_script", fields: ["adapter", "hook"]),
            variant(kind: "ax_action", fields: ["adapter", "hook"]),
            variant(kind: "apple_script", fields: ["adapter", "hook"]),
            variant(kind: "file_op", fields: ["operation", "source"]),
            variant(kind: "run_shell", fields: ["command", "scope"]),
        ])
    ])

    private static func variant(kind: String, fields: [String]) -> JSONValue {
        var properties: [String: JSONValue] = ["kind": .object(["const": .string(kind)])]
        var required: [JSONValue] = [.string("kind")]
        for field in fields {
            properties[field] = .object(["type": .string("string")])
            required.append(.string(field))
        }
        return .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required),
        ])
    }
}
