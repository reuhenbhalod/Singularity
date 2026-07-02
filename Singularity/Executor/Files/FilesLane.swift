//
//  FilesLane.swift
//  Singularity
//

import Foundation
import os

/// Lane 5 of the waterfall: file operations and the sandboxed shell
/// (brief §7, §8). Every path is re-validated by `FilePathValidator` and
/// every shell command by `ShellValidator` here too (defense-in-depth —
/// the `PlanValidator` already checked them). Deletes go to the Trash;
/// move/overwrite stages a copy first; shell runs under `sandbox-exec`.
@MainActor
final class FilesLane: ExecutorLane {
    private let pathValidator: FilePathValidator
    private let shellValidator: ShellValidator
    private let staging: StagingStore
    private let sandbox: any SandboxRunner
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "executor")

    init(
        pathValidator: FilePathValidator = FilePathValidator(),
        shellValidator: ShellValidator = ShellValidator(),
        staging: StagingStore = StagingStore(),
        sandbox: any SandboxRunner = SandboxExecRunner()
    ) {
        self.pathValidator = pathValidator
        self.shellValidator = shellValidator
        self.staging = staging
        self.sandbox = sandbox
    }

    func canHandle(_ step: PlanStep) -> Bool {
        switch step.action {
        case .fileOp, .runShell: return true
        default: return false
        }
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        switch step.action {
        case .fileOp(let operation, let source, let destination):
            return runFileOp(operation: operation, source: source, destination: destination)
        case .runShell(let command, let scope):
            return await runShell(command: command, scope: scope)
        default:
            return .unhandled(reason: "I don't have a way to do that yet.")
        }
    }

    private func runFileOp(operation: String, source: String, destination: String?) -> LaneResult {
        guard case .ok(let src) = pathValidator.validate(source) else {
            if case .rejected(let reason) = pathValidator.validate(source) {
                return .handled(summary: "I can't touch that — \(reason).")
            }
            return .handled(summary: "That path isn't valid.")
        }

        switch operation.lowercased() {
        case "list":
            let items = (try? FileOperations.list(src)) ?? []
            return .handled(
                summary: items.isEmpty ? "\(src.lastPathComponent) is empty" : items.joined(separator: ", "))

        case "trash":
            do {
                _ = try FileOperations.trash(src)
                return .handled(summary: "Moved \(src.lastPathComponent) to the Trash.")
            } catch {
                return .handled(summary: "Couldn't trash \(src.lastPathComponent).")
            }

        case "move", "copy":
            guard let destination, case .ok(let dst) = pathValidator.validate(destination) else {
                return .handled(summary: "That \(operation) needs a valid destination in your home folder.")
            }
            do {
                try? staging.stage(src)  // safety net before mutating
                if operation.lowercased() == "move" {
                    try FileOperations.move(src, to: dst)
                } else {
                    try FileOperations.copy(src, to: dst)
                }
                return .handled(summary: "\(operation == "move" ? "Moved" : "Copied") \(src.lastPathComponent).")
            } catch {
                return .handled(summary: "Couldn't \(operation) \(src.lastPathComponent).")
            }

        default:
            return .handled(summary: "I don't know the file operation \"\(operation)\".")
        }
    }

    private func runShell(command: String, scope: String) async -> LaneResult {
        if case .rejected(let rule) = shellValidator.validate(command) {
            return .handled(summary: "I won't run that command (\(rule)).")
        }
        guard case .ok(let scopeURL) = pathValidator.validate(scope) else {
            return .handled(summary: "That command's working folder isn't allowed.")
        }
        do {
            let result = try await sandbox.run(command, scope: scopeURL)
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .handled(summary: output.isEmpty ? "Done (exit \(result.exitCode))." : output)
        } catch {
            logger.error("shell run failed: \(String(describing: error), privacy: .public)")
            return .handled(summary: "Couldn't run that command.")
        }
    }
}
