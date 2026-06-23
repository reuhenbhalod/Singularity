//
//  JSONValueTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct JSONValueTests {
    /// A nested value round-trips through encode/decode unchanged.
    @Test func roundTripsNestedValue() throws {
        let value: JSONValue = .object([
            "type": .string("object"),
            "count": .int(3),
            "ratio": .double(1.5),
            "required": .bool(true),
            "items": .array([.string("a"), .null]),
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        #expect(decoded == value)
    }

    /// `true`/`false` decode as `.bool`, not as numbers.
    @Test func booleansDecodeAsBool() throws {
        let data = Data(#"{"flag": true}"#.utf8)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == .object(["flag": .bool(true)]))
    }

    /// Whole numbers stay integers; fractional stays double.
    @Test func numbersKeepIntVsDouble() throws {
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data("7".utf8)) == .int(7))
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data("7.5".utf8)) == .double(7.5))
    }

    /// `OllamaFormat` encodes as the bare string "json" or the schema.
    @Test func ollamaFormatEncoding() throws {
        let json = try JSONEncoder().encode(OllamaFormat.json)
        #expect(String(data: json, encoding: .utf8) == "\"json\"")

        let schema = try JSONEncoder().encode(OllamaFormat.schema(.object(["type": .string("object")])))
        #expect(String(data: schema, encoding: .utf8) == #"{"type":"object"}"#)
    }
}
