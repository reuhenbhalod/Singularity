//
//  OllamaClientError.swift
//  Singularity
//

import Foundation

/// Transport-level failures talking to the Ollama HTTP server. The
/// planner (T-P2-04) maps these onto its own user-facing `PlannerError`.
enum OllamaClientError: Error, Equatable {
    /// The server couldn't be reached (not running, wrong host/port).
    case unreachable
    /// The request exceeded the configured timeout.
    case timeout
    /// The server responded with a non-2xx status.
    case server(status: Int)
    /// Some other transport failure.
    case transport(String)
    /// The response body couldn't be decoded into the expected shape.
    case decoding(String)
}
