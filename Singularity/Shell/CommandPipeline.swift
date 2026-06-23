//
//  CommandPipeline.swift
//  Singularity
//

import Foundation
import os

/// Orchestrates one command end to end: echo it to the log, validate
/// the input, plan it, execute it, and log the outcome.
///
/// Phase 2 wiring: `InputValidator` -> planner (`OllamaPlanner` in the
/// app, any `PlannerProtocol` for tests) -> `ValidatedPlan.phase1Allow`
/// (stub validator, replaced by the real `PlanValidator` in T-P5-05) ->
/// `ExecutorRouter`.
///
/// `run` never throws — every failure becomes a log line so the shell
/// stays responsive and the user always gets feedback.
@MainActor
final class CommandPipeline {
    private let planner: any PlannerProtocol
    private let router: ExecutorRouter
    private let log: SessionLogStore
    private let validator: InputValidator
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "pipeline")

    init(planner: any PlannerProtocol, router: ExecutorRouter, log: SessionLogStore) {
        self.planner = planner
        self.router = router
        self.log = log
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

        do {
            guard let raw = try await planner.plan(clean) else {
                log.append(kind: .system, "I don't know how to do that yet.")
                return
            }
            // Phase-2 stub validator; T-P5-05 swaps in the real
            // PlanValidator as the only producer of ValidatedPlan.
            let validated = ValidatedPlan.phase1Allow(raw)
            switch try await router.dispatch(validated) {
            case .handled(let summary):
                log.append(kind: .result, summary)
            case .unhandled:
                log.append(kind: .system, "I couldn't handle that step.")
            }
        } catch let error as PlannerError {
            log.append(kind: .system, Self.message(for: error))
        } catch {
            logger.error("dispatch failed: \(String(describing: error), privacy: .public)")
            log.append(kind: .system, "Something went wrong running that.")
        }
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
