//
//  CommandPipeline.swift
//  Singularity
//

import Foundation
import os

/// Orchestrates one command end to end: echo it to the log, plan it,
/// validate it (Phase-1 stub), execute it, and log the outcome.
///
/// Phase 1 wires `StringMatcherPlanner` -> `ValidatedPlan.phase1Allow`
/// -> `ExecutorRouter`. Phase 2 swaps the planner for `OllamaPlanner`
/// and Phase 5 replaces the stub validator with the real
/// `PlanValidator`; this pipeline's shape stays the same.
///
/// `run` never throws — every failure becomes a log line so the shell
/// stays responsive and the user always gets feedback.
@MainActor
final class CommandPipeline {
    private let planner: any PlannerProtocol
    private let router: ExecutorRouter
    private let log: SessionLogStore
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "pipeline")

    init(planner: any PlannerProtocol, router: ExecutorRouter, log: SessionLogStore) {
        self.planner = planner
        self.router = router
        self.log = log
    }

    func run(_ input: String) async {
        log.append(kind: .command, input)
        do {
            guard let raw = try await planner.plan(input) else {
                log.append(kind: .system, "I don't know how to do that yet.")
                return
            }
            // Phase-1 stub validator; T-P5-05 swaps in the real
            // PlanValidator as the only producer of ValidatedPlan.
            let validated = ValidatedPlan.phase1Allow(raw)
            let summary = try await router.dispatch(validated)
            log.append(kind: .result, summary)
        } catch {
            logger.error("dispatch failed: \(String(describing: error), privacy: .public)")
            log.append(kind: .system, "Something went wrong running that.")
        }
    }
}
