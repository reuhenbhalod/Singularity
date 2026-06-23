//
//  OllamaChatResponse.swift
//  Singularity
//

import Foundation

/// The `/api/chat` response (with `stream: false`). The planner reads
/// `message.content`, which holds the model's JSON plan text.
struct OllamaChatResponse: Decodable, Sendable, Equatable {
    let model: String
    let message: OllamaMessage
    let done: Bool
}
