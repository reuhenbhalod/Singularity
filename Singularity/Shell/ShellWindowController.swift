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

        let screen = currentCursorScreen()
        let panel = ShellPanel(contentRect: screen.frame)
        panel.setFrame(screen.frame, display: true)
        // Per-show stores. Principle 4 (no cross-session memory) is
        // preserved because hide() drops these references and clears
        // them explicitly.
        let log = SessionLogStore()
        let comp = CompositorStore()
        let inputViewModel = CommandInputViewModel()
        // Phase-2 command pipeline: input validator -> Ollama planner
        // -> stub validator -> executor router (live WebKit driver). The
        // router and pipeline log into this show's SessionLogStore.
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
                WebLane(compositor: comp),
            ]),
            log: log
        )
        // Panic stop: typing the panic phrase (`abort`) cancels the
        // in-flight command instead of queuing a new one (US-SAFE-7).
        let panic = PanicController()
        inputViewModel.onSubmit = { [logger, weak log] text in
            if panic.isPanicPhrase(text) {
                panic.panic()
                log?.append(kind: .system, "Stopped.")
                return
            }
            logger.info("submit: \(text, privacy: .public)")
            panic.track(Task { await pipeline.run(text) })
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
        panel.contentView = NSHostingView(
            rootView: ShellRootView(
                commandInputViewModel: inputViewModel,
                sessionLog: log,
                compositor: comp
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
        logger.info("show: panel on screen \(screen.frame.debugDescription, privacy: .public)")
    }

    func hide() {
        guard isShowing, let panel else { return }

        // Explicit clear per T-P0-09 / T-P0-11 acceptance. Stores
        // are also dropped below; clear() ensures nothing leaks if
        // a reference is held by a view that outlives the hide.
        sessionLog?.clear()
        compositor?.clear()

        panel.orderOut(nil)
        self.panel = nil
        sessionLog = nil
        commandInput = nil
        compositor = nil
        pipeline = nil

        NSApp.presentationOptions = savedPresentationOptions

        // Returns focus to whatever app was frontmost before we summoned.
        // Without this, focus stays "in nowhere" because our accessory
        // app has no Dock icon / standard window to fall back to.
        NSApp.hide(nil)

        isShowing = false
        logger.info("hide: panel ordered out")
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
