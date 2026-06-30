//
//  AXLane.swift
//  Singularity
//

import Foundation
import os

/// Lane 3 of the waterfall: drives native apps via Accessibility
/// (research brief §5). Handles `ax_action(adapter:hook:)` steps by
/// resolving the named `AXAdapter`, attaching to the running app's AX
/// tree, and running the hook.
///
/// Failures degrade into status strings rather than throwing — a
/// missing app, a revoked permission, or an unfound control should tell
/// the user what happened, not crash the shell.
@MainActor
final class AXLane: ExecutorLane {
    private let registry: AXAdapterRegistry
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "executor")

    init(registry: AXAdapterRegistry = AXAdapterRegistry()) {
        self.registry = registry
    }

    func canHandle(_ step: PlanStep) -> Bool {
        guard case .axAction(let adapter, let hook) = step.action else { return false }
        return registry.adapter(named: adapter)?.hooks.contains(hook) ?? false
    }

    func diagnose(_ step: PlanStep) -> String? {
        guard case .axAction(let adapterName, let hook) = step.action else { return nil }
        guard let adapter = registry.adapter(named: adapterName) else {
            return "I can't control \(adapterName) as a native app yet."
        }
        let supported = adapter.hooks.sorted().joined(separator: ", ")
        return "I can't \"\(hook)\" \(adapter.name) — what I can do there: \(supported)."
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        guard case .axAction(let adapterName, let hook) = step.action,
            let adapter = registry.adapter(named: adapterName)
        else {
            return .unhandled(reason: diagnose(step) ?? "I don't have a way to do that yet.")
        }

        guard let app = AXApplication(bundleId: adapter.bundleID) else {
            return .handled(summary: "\(adapter.name) isn't running")
        }

        do {
            return .handled(summary: try adapter.perform(hook, in: app))
        } catch AXErrors.notAuthorized {
            return .handled(summary: "I need Accessibility permission to control \(adapter.name)")
        } catch AXErrors.elementUnavailable {
            return .handled(summary: "couldn't find the control in \(adapter.name)")
        } catch {
            logger.error("ax \(hook, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return .handled(summary: "couldn't \(hook) \(adapter.name)")
        }
    }
}
