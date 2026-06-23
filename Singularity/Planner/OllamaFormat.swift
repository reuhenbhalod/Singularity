//
//  OllamaFormat.swift
//  Singularity
//

import Foundation

/// The `format` value sent to Ollama's `/api/chat`: either loose JSON
/// mode (`"json"`) or a full JSON Schema that constrains generation
/// token-by-token (research brief §1). Encodes as a bare string or a
/// schema object, matching what the API expects.
enum OllamaFormat: Encodable, Sendable, Equatable {
    case json
    case schema(JSONValue)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .json: try container.encode("json")
        case .schema(let value): try container.encode(value)
        }
    }
}
