//
//  CommandPipeline.swift
//  Singularity
//

import Foundation
import os

/// Orchestrates one command end to end: echo it to the log, validate
/// the input, plan it, execute it, and log the outcome.
///
/// Wiring: `InputValidator` -> planner (`OllamaPlanner` in the app, any
/// `PlannerProtocol` for tests) -> `PlanValidator` (the sole producer of
/// `ValidatedPlan`) -> `ExecutorRouter`. A rejected plan surfaces its
/// reason in the log and never reaches the executor.
///
/// `run` never throws — every failure becomes a log line so the shell
/// stays responsive and the user always gets feedback.
@MainActor
final class CommandPipeline {
    private let planner: any PlannerProtocol
    private let router: ExecutorRouter
    private let log: SessionLogStore
    private let validator: InputValidator
    private let planValidator: PlanValidator
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "pipeline")

    init(
        planner: any PlannerProtocol,
        router: ExecutorRouter,
        log: SessionLogStore,
        planValidator: PlanValidator = PlanValidator()
    ) {
        self.planner = planner
        self.router = router
        self.log = log
        self.planValidator = planValidator
        self.validator = InputValidator(warn: { [log] line in log.append(kind: .system, line) })
    }

    func run(_ input: String) async {
        // Boundary first — normalize, scan for secrets, cap, rate-limit
        // — BEFORE echoing, so a secret in the raw input never lands in
        // the log via the command echo. A blocked input never reaches
        // the planner; the validator has already logged why.
        guard case .submit(let clean) = validator.validate(input) else {
            return
        }
        log.append(kind: .command, clean)

        // Debug commands (e.g. `axdump <bundle id>`) run locally and
        // never reach the planner or executor.
        if runDebugCommand(clean) {
            return
        }

        do {
            guard let raw = try await planner.plan(clean) else {
                log.append(kind: .system, "I don't know how to do that yet.")
                return
            }
            // The real safety gate: PlanValidator is the only producer of
            // ValidatedPlan, and the router accepts nothing else.
            switch planValidator.validate(raw) {
            case .failure(let rejection):
                SafetyLog.planRejected(reason: rejection.reasonLabel, planHash: rejection.planHash)
                log.append(kind: .system, rejection.humanMessage)
            case .success(let validated):
                switch try await router.dispatch(validated) {
                case .handled(let summary):
                    log.append(kind: .result, summary)
                case .unhandled(let reason):
                    log.append(kind: .system, reason)
                }
            }
        } catch let error as PlannerError {
            log.append(kind: .system, Self.message(for: error))
        } catch {
            logger.error("dispatch failed: \(String(describing: error), privacy: .public)")
            log.append(kind: .system, "Something went wrong running that.")
        }
    }

    /// Handles local debug commands without invoking the planner.
    /// Returns whether the input was a debug command. Currently:
    /// `axdump <bundle id>` prints the target app's Accessibility tree
    /// into the session log (T-P4-08).
    private func runDebugCommand(_ input: String) -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.first?.lowercased() == "axdump" else { return false }
        guard parts.count == 2, !parts[1].trimmingCharacters(in: .whitespaces).isEmpty else {
            log.append(kind: .system, "Usage: axdump <bundle id>  —  e.g. axdump com.apple.finder")
            return true
        }
        let bundleId = parts[1].trimmingCharacters(in: .whitespaces)
        log.append(kind: .result, AXDump.dump(bundleId: bundleId))
        return true
    }

    private static func message(for error: PlannerError) -> String {
        switch error {
        case .unparseable: return "I didn't understand that — try rephrasing."
        case .unreachable: return "Can't reach the planner — is Ollama running?"
        case .timeout: return "The planner took too long. Try again."
        case .transport: return "The planner hit an error. Try again."
        }
    }
}
