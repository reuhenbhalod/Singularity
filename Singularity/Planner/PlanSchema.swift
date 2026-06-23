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
                        "action": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "kind": .object([
                                    "type": .string("string"),
                                    "enum": .array([
                                        .string("open_url"),
                                        .string("web_navigate"),
                                        .string("web_evaluate"),
                                        .string("run_script"),
                                    ]),
                                ]),
                                "url": .object(["type": .string("string")]),
                                "script": .object(["type": .string("string")]),
                                "adapter": .object(["type": .string("string")]),
                                "hook": .object(["type": .string("string")]),
                            ]),
                            "required": .array([.string("kind")]),
                        ])
                    ]),
                    "required": .array([.string("action")]),
                ]),
            ])
        ]),
        "required": .array([.string("steps")]),
    ])

    /// The schema wrapped for Ollama's `format` parameter.
    static var ollamaFormat: OllamaFormat { .schema(json) }
}
