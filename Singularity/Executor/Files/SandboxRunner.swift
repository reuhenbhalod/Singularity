//
//  SandboxRunner.swift
//  Singularity
//

import Foundation

/// The result of a sandboxed shell command.
struct ShellResult: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

/// Runs a validated shell command inside a tight sandbox (brief §8). An
/// abstraction so the `sandbox-exec` implementation can be swapped if
/// Apple ever pulls the (deprecated but functional) binary.
protocol SandboxRunner: Sendable {
    func run(_ command: String, scope: URL) async throws -> ShellResult
}

/// Runs commands under `/usr/bin/sandbox-exec` with a profile that denies
/// network, denies writes outside `scope`, and denies process-exec except
/// a whitelist of utilities.
struct SandboxExecRunner: SandboxRunner {
    func run(_ command: String, scope: URL) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
                process.arguments = [
                    "-p", SandboxProfile.source(scope: scope), "/bin/zsh", "-c", command,
                ]
                process.currentDirectoryURL = scope

                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err

                do {
                    try process.run()
                    let outData = out.fileHandleForReading.readDataToEndOfFile()
                    let errData = err.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(
                        returning: ShellResult(
                            stdout: String(data: outData, encoding: .utf8) ?? "",
                            stderr: String(data: errData, encoding: .utf8) ?? "",
                            exitCode: process.terminationStatus))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
