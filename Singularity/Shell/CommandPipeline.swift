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
    private let authGate: any AuthorizationGate
    private let confirmGate: any ConfirmGate
    private let routineStore: RoutineStore
    private let routineHandler: RoutineCommandHandler
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "pipeline")

    init(
        planner: any PlannerProtocol,
        router: ExecutorRouter,
        log: SessionLogStore,
        planValidator: PlanValidator = PlanValidator(),
        authGate: (any AuthorizationGate)? = nil,
        confirmGate: any ConfirmGate = DenyingConfirmGate(),
        routineStore: RoutineStore = RoutineStore()
    ) {
        self.planner = planner
        self.router = router
        self.log = log
        self.planValidator = planValidator
        self.authGate = authGate ?? DeviceAuthorizationGate()
        self.confirmGate = confirmGate
        self.routineStore = routineStore
        self.routineHandler = RoutineCommandHandler(
            store: routineStore,
            log: { kind, text in log.append(kind: kind, text) })
        self.validator = InputValidator(warn: { [log] line in log.append(kind: .system, line) })
    }

    func run(_ input: String) async {
        await run(input, isRoutineStep: false)
    }

    /// Runs one command. `isRoutineStep` is true when this call is an
    /// expanded step of a routine — such steps skip routine handling and
    /// resolution entirely, so a routine can never invoke another routine
    /// or recurse (spec §6 #15).
    private func run(_ input: String, isRoutineStep: Bool) async {
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
        if !isRoutineStep, runDebugCommand(clean) {
            return
        }

        // Routines: management commands (create/list/delete) are handled
        // inline; an invocation expands to its steps, each re-entering the
        // pipeline as if typed. Both are top-level only.
        if !isRoutineStep {
            if await routineHandler.handle(clean) {
                return
            }
            let routines = await routineStore.all()
            let map = Dictionary(routines.map { ($0.name, $0.steps) }) { first, _ in first }
            switch RoutineResolver(routines: map).resolve(clean) {
            case .expanded(let name, let steps):
                log.append(
                    kind: .system,
                    "Routine '\(name)' → \(steps.count) step\(steps.count == 1 ? "" : "s").")
                for (index, step) in steps.enumerated() {
                    if Task.isCancelled {
                        log.append(
                            kind: .system,
                            "Routine '\(name)' aborted — \(index) of \(steps.count) steps ran.")
                        return
                    }
                    await run(step, isRoutineStep: true)
                }
                return
            case .notFound(let name):
                log.append(kind: .system, "No routine named '\(name)'.")
                return
            case .passthrough:
                break
            }
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
                guard await passesGates(validated) else { return }
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

    /// Runs the risk gates for a validated plan: Touch ID for
    /// destructive/spend, then an explicit confirm for anything mutating.
    /// Returns whether the plan may proceed. Today every action is
    /// `.read`, so this passes straight through — the wiring is here for
    /// when Phase 6 adds file/spend actions.
    private func passesGates(_ plan: ValidatedPlan) async -> Bool {
        let risk = plan.steps.map { RiskClass.default(for: $0.action) }.max() ?? .read

        if risk >= DeviceAuthorizationGate.threshold {
            if await authGate.authorize(action: "this command", risk: risk) == .denied {
                log.append(kind: .system, "Cancelled — authentication is required for that.")
                return false
            }
        }
        if risk >= .reversible {
            let approved = await confirmGate.confirm(
                ConfirmPreview(title: "Confirm this action", detail: "Go ahead and run it?"))
            if !approved {
                log.append(kind: .system, "Cancelled.")
                return false
            }
        }
        return true
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
