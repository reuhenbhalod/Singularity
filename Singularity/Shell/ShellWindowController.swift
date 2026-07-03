//
//  ShellWindowController.swift
//  Singularity
//

import AppKit
import SwiftUI
import os

/// Owns the `ShellPanel` lifecycle: show/hide on hotkey, screen-of-
/// cursor sizing for multi-monitor, presentation-option swapping
/// (hides menu bar + Dock while visible), and focus return to the
/// prior app on dismiss.
///
/// Per research brief §2: panel sizes to the screen containing the
/// cursor at summon time, not always the primary display. Per
/// architect T-P0-06 notes: `presentationOptions` are swapped on
/// show / restored on hide; on hide we call `NSApp.hide(nil)` so the
/// system returns focus to the previously frontmost app (the
/// Raycast / Alfred pattern).
///
/// Ordering matters in `show()`: `presentationOptions` are only
/// honored while the app is the *active* application, so the
/// activation call must come first. Using
/// `activate(ignoringOtherApps:)` (deprecated since macOS 14 but
/// still works) because the new polite `activate()` can refuse to
/// steal focus from a foreground app — which is exactly what a
/// hotkey-summoned shell needs to do.
@MainActor
final class ShellWindowController {
    private var panel: ShellPanel?
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private(set) var isShowing = false
    private var commandInput: CommandInputViewModel?
    private var sessionLog: SessionLogStore?
    private var compositor: CompositorStore?
    private var pipeline: CommandPipeline?
    private var permissions: PermissionsManager?
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "shell")

    func toggle() {
        if isShowing {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard !isShowing else { return }
        let summonStart = DispatchTime.now()

        let screen = currentCursorScreen()
        let panel = ShellPanel(contentRect: screen.frame)
        panel.setFrame(screen.frame, display: true)
        // Per-show stores. Principle 4 (no cross-session memory) is
        // preserved because hide() drops these references and clears
        // them explicitly.
        let log = SessionLogStore()
        let comp = CompositorStore()
        let inputViewModel = CommandInputViewModel()
        // Live settings (read from the same UserDefaults the Settings UI
        // writes) — the NSFW toggle and panic phrase take effect here.
        let settings = SettingsStore()
        // Confirm gate that presents in the shell (fires for the file /
        // shell actions from Phase 6 onward).
        let confirmGate = ShellConfirmGate()
        // Live permission state: polled while the shell is up so a
        // mid-session revocation surfaces a non-blocking banner (T-P7-09).
        let permissions = PermissionsManager()
        permissions.startPolling()
        // Command pipeline: input validation -> Ollama planner ->
        // PlanValidator -> risk gates -> executor router. Logs into this
        // show's SessionLogStore.
        let pipeline = CommandPipeline(
            planner: OllamaPlanner(client: OllamaClient()),
            router: ExecutorRouter(lanes: [
                URLSchemeLane(),
                AXLane(onPermissionRevoked: { [weak log] in
                    log?.append(
                        kind: .banner,
                        "Accessibility was revoked — re-enable it in System Settings "
                            + "→ Privacy & Security → Accessibility.")
                }),
                AppleScriptLane(onAutomationResult: { [weak permissions] code in
                    Task { @MainActor in permissions?.recordAutomationResult(errorCode: code) }
                }),
                WebLane(compositor: comp),
                FilesLane(),
            ]),
            log: log,
            planValidator: PlanValidator(
                urlPolicy: URLPolicy(nsfwEnabled: settings.nsfwFilterEnabled)),
            confirmGate: confirmGate
        )
        // Panic stop: typing the panic phrase (`abort`) cancels the
        // in-flight command instead of queuing a new one (US-SAFE-7).
        let panic = PanicController()
        panic.panicPhrase = settings.panicPhrase
        inputViewModel.onSubmit = { [logger, weak log, weak self] text in
            if panic.isPanicPhrase(text) {
                panic.panic()
                log?.append(kind: .system, "Stopped.")
                return
            }
            // "settings" opens the Settings window (dismissing the shell,
            // which sits above everything).
            if text.trimmingCharacters(in: .whitespaces).lowercased() == "settings" {
                self?.hide()
                Latency.measure("settings_open") { Self.openSettingsWindow() }
                return
            }
            logger.info("submit: \(text, privacy: .public)")
            panic.track(Task { await Latency.measureAsync("command_return_to_result") { await pipeline.run(text) } })
        }
        inputViewModel.onLog = { [weak log, logger] line in
            log?.append(kind: .system, line)
            logger.info("input log: \(line, privacy: .public)")
        }
        inputViewModel.onDismiss = { [weak self] in
            self?.hide()
        }
        commandInput = inputViewModel
        sessionLog = log
        compositor = comp
        self.pipeline = pipeline
        self.permissions = permissions
        panel.contentView = NSHostingView(
            rootView: ShellRootView(
                commandInputViewModel: inputViewModel,
                sessionLog: log,
                compositor: comp,
                confirmGate: confirmGate,
                permissions: permissions,
                onOpenSettings: { [weak self] in
                    self?.hide()
                    Self.openSettingsWindow()
                }
            )
        )
        self.panel = panel

        // Activate first so presentationOptions take effect; Apple's
        // docs say those options are only honored for the active app.
        NSApp.activate(ignoringOtherApps: true)
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideMenuBar, .hideDock]
        panel.makeKeyAndOrderFront(nil)

        isShowing = true
        // Hotkey-to-focus budget is 150ms (US-S-1); this is pure AppKit.
        Latency.logElapsed("hotkey_to_focus", since: summonStart)
        logger.info("show: panel on screen \(screen.frame.debugDescription, privacy: .public)")
    }

    func hide() {
        guard isShowing, let panel else { return }

        // Explicit clear per T-P0-09 / T-P0-11 acceptance. Stores
        // are also dropped below; clear() ensures nothing leaks if
        // a reference is held by a view that outlives the hide.
        sessionLog?.clear()
        compositor?.clear()

        permissions?.stopPolling()

        panel.orderOut(nil)
        self.panel = nil
        sessionLog = nil
        commandInput = nil
        compositor = nil
        pipeline = nil
        permissions = nil

        NSApp.presentationOptions = savedPresentationOptions

        // Returns focus to whatever app was frontmost before we summoned.
        // Without this, focus stays "in nowhere" because our accessory
        // app has no Dock icon / standard window to fall back to.
        NSApp.hide(nil)

        isShowing = false
        logger.info("hide: panel ordered out")
    }

    /// Opens the SwiftUI `Settings` scene. The accessory app has no menu
    /// bar, so the shell summons Settings via the app's action selector.
    private static func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    /// Returns the `NSScreen` whose frame contains the mouse cursor,
    /// or the main screen as a fallback.
    private func currentCursorScreen() -> NSScreen {
        let location = NSEvent.mouseLocation
        for screen in NSScreen.screens where screen.frame.contains(location) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
