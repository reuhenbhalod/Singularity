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

    /// The schema encodes to JSON and declares every action kind.
    @Test func schemaDeclaresEveryActionKind() throws {
        let data = try JSONEncoder().encode(PlanSchema.json)
        let string = try #require(String(data: data, encoding: .utf8))

        for kind in ["open_url", "web_navigate", "web_evaluate", "run_script"] {
            #expect(string.contains(kind), "schema should list action kind \(kind)")
        }
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
