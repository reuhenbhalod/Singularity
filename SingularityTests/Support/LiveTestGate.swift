//
//  LiveTestGate.swift
//  SingularityTests
//

import XCTest

@testable import Singularity

/// Gate for tests that drive a real Ollama server. These are
/// integration tests, not unit tests: a live 7B model is only ~reliable
/// (not deterministic), and running several live test classes in
/// parallel makes Ollama batch the requests, which shifts the output.
///
/// So they only run when a marker is present — keeping the default
/// `xcodebuild test` suite deterministic and green.
///
/// Enable them either way:
/// - From the CLI: `touch /tmp/singularity-live-tests` then run with
///   `-parallel-testing-enabled NO` (serial keeps the model output the
///   same as in-isolation). The env var does not reach the test host
///   over the CLI, so the file marker is the reliable CLI switch.
/// - From Xcode: set `SINGULARITY_LIVE_OLLAMA=1` in the scheme's Test
///   environment.
enum LiveTestGate {
    static let fileMarkerPath = "/tmp/singularity-live-tests"

    /// Throws `XCTSkip` unless a live marker is present and Ollama is
    /// reachable.
    static func requireLiveOllama() async throws {
        let enabled =
            ProcessInfo.processInfo.environment["SINGULARITY_LIVE_OLLAMA"] != nil
            || FileManager.default.fileExists(atPath: fileMarkerPath)
        guard enabled else {
            throw XCTSkip(
                "Live Ollama tests are gated. Set SINGULARITY_LIVE_OLLAMA=1 (Xcode) or "
                    + "`touch \(fileMarkerPath)` (CLI) to run them.")
        }
        do {
            _ = try await OllamaClient(timeout: 120).tags()
        } catch {
            throw XCTSkip("Ollama not reachable at localhost:11434 — live test skipped.")
        }
    }
}
