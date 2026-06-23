//
//  PlanSchemaTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct PlanSchemaTests {
    /// The Ollama `format` wraps the plan schema.
    @Test func ollamaFormatIsSchema() {
        guard case .schema(let value) = PlanSchema.ollamaFormat else {
            Issue.record("expected .schema, got \(PlanSchema.ollamaFormat)")
            return
        }
        #expect(value == PlanSchema.json)
    }

    /// The schema encodes to JSON and declares the planner's action
    /// kinds. `web_evaluate` is intentionally excluded so the model
    /// can't emit raw JavaScript.
    @Test func schemaDeclaresPlannerActionKinds() throws {
        let data = try JSONEncoder().encode(PlanSchema.json)
        let string = try #require(String(data: data, encoding: .utf8))

        for kind in ["open_url", "web_navigate", "run_script"] {
            #expect(string.contains(kind), "schema should list action kind \(kind)")
        }
        #expect(!string.contains("web_evaluate"), "planner schema must not expose web_evaluate")
    }

    /// `run_script` requires both adapter and hook (the discriminated
    /// union enforces per-kind fields the decoder needs).
    @Test func runScriptVariantRequiresAdapterAndHook() throws {
        let data = try JSONEncoder().encode(PlanSchema.json)
        let string = try #require(String(data: data, encoding: .utf8))
        #expect(string.contains("oneOf"))
        #expect(string.contains("hook"))
        #expect(string.contains("adapter"))
    }

    /// The top-level object requires `steps`.
    @Test func schemaRequiresSteps() throws {
        guard case .object(let root) = PlanSchema.json,
            case .array(let required)? = root["required"]
        else {
            Issue.record("expected a top-level object with a required array")
            return
        }
        #expect(required.contains(.string("steps")))
    }
}
