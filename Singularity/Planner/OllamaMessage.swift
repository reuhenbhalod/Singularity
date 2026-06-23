//
//  OllamaMessage.swift
//  Singularity
//

import Foundation

/// One message in an Ollama `/api/chat` exchange. `role` is
/// `"system"`, `"user"`, or `"assistant"`.
struct OllamaMessage: Codable, Sendable, Equatable {
    let role: String
    let content: String
}
