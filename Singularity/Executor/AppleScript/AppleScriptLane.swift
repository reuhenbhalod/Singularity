//
//  AppleScriptLane.swift
//  Singularity
//

import Foundation
import os

/// Lane 4 of the waterfall: drives Apple-native apps via AppleScript
/// (research brief §6). Handles `apple_script(adapter:hook:)` by resolving
/// the named `AppleScriptAdapter`, compiling its script (cached), and
/// running it. Failures — including a denied Automation prompt
/// (`errAEEventNotPermitted`, -1743) — degrade into a clean status line.
///
/// Live use requires the `NSAppleEventsUsageDescription` Info.plist string
/// and, on first dispatch to each target app, the per-app Automation
/// consent (System Settings → Privacy & Security → Automation).
@MainActor
final class AppleScriptLane: ExecutorLane {
    private let registry: AppleScriptAdapterRegistry
    private let cache = CompiledScriptCache()
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "executor")

    /// errAEEventNotPermitted — Automation consent was denied.
    private static let notPermitted = -1743

    init(registry: AppleScriptAdapterRegistry = AppleScriptAdapterRegistry()) {
        self.registry = registry
    }

    func canHandle(_ step: PlanStep) -> Bool {
        guard case .appleScript(let adapter, let hook) = step.action else { return false }
        return registry.adapter(named: adapter)?.scripts[hook] != nil
    }

    func diagnose(_ step: PlanStep) -> String? {
        guard case .appleScript(let adapterName, let hook) = step.action else { return nil }
        guard let adapter = registry.adapter(named: adapterName) else {
            return "I can't control \(adapterName) via AppleScript yet."
        }
        let supported = adapter.scripts.keys.sorted().joined(separator: ", ")
        return "I can't \"\(hook)\" \(adapter.name) — what I can do there: \(supported)."
    }

    func execute(_ step: PlanStep) async throws -> LaneResult {
        guard case .appleScript(let adapterName, let hook) = step.action,
            let adapter = registry.adapter(named: adapterName),
            let source = adapter.scripts[hook]
        else {
            return .unhandled(reason: diagnose(step) ?? "I don't have a way to do that yet.")
        }

        guard let script = cache.script(for: source) else {
            return .handled(summary: "couldn't prepare the \(adapterName) command")
        }

        var errorInfo: NSDictionary?
        let output = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if code == Self.notPermitted {
                return .handled(
                    summary: "I need permission to control \(adapter.name) — grant it in "
                        + "System Settings → Privacy & Security → Automation.")
            }
            logger.error(
                "applescript \(hook, privacy: .public) failed code=\(code, privacy: .public)")
            return .handled(summary: "couldn't \(hook) \(adapter.name)")
        }

        if let text = output.stringValue, !text.isEmpty {
            return .handled(summary: text)
        }
        return .handled(summary: "done: \(hook) \(adapter.name)")
    }
}
