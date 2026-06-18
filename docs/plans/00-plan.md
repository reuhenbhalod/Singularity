# 00 — Implementation Plan (v1)

This plan turns the approved v1 spec (`docs/specs/00-spec.md`) into an ordered, atomic task list that an implementer can execute one task at a time. It is the source of truth for build progress. The phase order is locked by `Singularity.md` §8 (skeleton → hero → planner → router + easy lanes → AX → safety → system/file lanes → polish); within each phase tasks are ordered so the app remains runnable at every step.

---

## 1. Plan summary

This plan covers v1 of Singularity end-to-end: all 39 user stories from `docs/specs/00-spec.md` mapped into 96 atomic tasks across the 8 locked phases (0–7). It is organized by phase, then by task. Every task has a stable ID (`T-PN-NN`), cites the user stories it advances, cites the research-brief sections it draws from, lists its dependencies, and states a concrete acceptance check.

The contract with the implementer is simple. Pick up one task at a time, in order, top to bottom. Mark `[x]` only after the acceptance check passes locally — that means `xcodebuild test` is green, `swiftlint` is clean, `swift-format` is clean, `xcodebuild build` succeeds, and the specific acceptance check listed on the task is satisfied (per CLAUDE.md "Definition of done"). If a task surfaces a product question (a behavior the spec did not pin down), stop and raise back to the user rather than guessing — the spec §11 and architect §8 are intentionally empty and any new question should be added there explicitly before proceeding.

Some tasks are marked `[USER]`. Those require a human action the agent cannot perform (install Ollama, grant TCC permissions in System Settings, register an App ID with Apple Developer, generate an iCloud Container ID, etc.). The implementer must stop at those tasks, explain what is needed in plain language, and resume only after the user confirms it is done.

---

## 2. Architectural overview

Singularity is a single macOS app target, built in one Xcode project, with no third-party SPM dependencies in v1 (per CLAUDE.md). The source tree under `Singularity/` is sliced by responsibility, mirroring the folder convention in CLAUDE.md, with `SingularityTests/` mirroring it test-for-folder. There is **one** product target (`Singularity`) and **one** unit-test target (`SingularityTests`); no internal SPM packages are introduced — the folders are organizational, not modular, because adding a separate framework boundary for each folder would force `public` decoration of every type and adds zero value for a single-app codebase of this size.

```
┌──────────────────────────────────────────────────────────────────┐
│  App/   ── entry point, NSApplicationDelegate, hotkey wiring     │
│   │                                                                │
│   ▼                                                                │
│  Shell/  ── NSPanel host, command input, session log, compositor  │
│   │            │                                                   │
│   │            └─► Compositor/  ── pane tiling, pane container    │
│   ▼                                                                │
│  Routines/ ── RoutineStore + resolver (sits BEFORE planner)       │
│   │                                                                │
│   ▼                                                                │
│  Planner/  ── Ollama HTTP, strict-JSON schema, validate/repair    │
│   │             produces:  RawPlan                                 │
│   ▼                                                                │
│  Safety/  ── InputValidator, PlanValidator, URLPolicy,            │
│   │          AllowedDomains, NSFWBlocklist, AuthorizationGate,    │
│   │          ConfirmGate, UntrustedContentFilter, SafetyLog,      │
│   │          SandboxRunner                                         │
│   │             produces:  ValidatedPlan  (TYPE-LEVEL gate)        │
│   ▼                                                                │
│  Executor/  ── ExecutorRouter (accepts only ValidatedPlan)        │
│      ├─ URLScheme/      lane 1                                     │
│      ├─ Web/            lane 2 (WKWebView + adapters)              │
│      ├─ Accessibility/  lane 3 (AX wrapper + adapters)             │
│      ├─ AppleScript/    lane 4                                     │
│      └─ Files/          lane 5 (FileManager + SandboxRunner)       │
│                                                                    │
│  Adapters/  ── per-app web/AX/AppleScript adapter implementations  │
│  Identity/  ── AppleIDSignIn + IdentityStore (Keychain)            │
│  Settings/  ── SettingsStore (@Observable) + 7 tab views            │
│  Permissions/ ── PermissionsManager, SystemSettingsLinks            │
│  Resources/ ── nsfw-blocklist.txt, system prompt, JSON schema       │
└──────────────────────────────────────────────────────────────────┘
```

**Layer rules (the "do not break" interfaces).**

1. `Planner` produces only `RawPlan` (decoded but unvalidated). It cannot construct `ValidatedPlan`.
2. `Safety/PlanValidator` is the only producer of `ValidatedPlan`. Its initializer/constructor is `internal` to the `Safety` module-level access and the type cannot be constructed elsewhere — enforced by file-private init in `ValidatedPlan` plus a thin factory exposed only by `PlanValidator`.
3. `Executor/ExecutorRouter.dispatch(_:)` accepts **only** `ValidatedPlan`. There is no overload taking `RawPlan`. This is spec §6 decision #3 / brief §11.3, made type-level so it cannot be bypassed by accident.
4. `Routines/RoutineResolver` runs *before* `Planner` in the command pipeline (per US-RT-2 ordering). Each expanded step re-enters the whole pipeline.
5. Every read primitive (web pane `evaluateJavaScript` result, AX read, AppleScript output, file read) routes through `Safety/UntrustedContentFilter.wrap(...)` which returns an `EnvelopedContent` type that is the only thing the planner-context buffer accepts (per brief §11.6 / US-SAFE-6). `String` cannot be appended directly.
6. Every URL open (lane 1, lane 2 nav delegate, lane 5 `open …`) goes through `Safety/URLPolicy.evaluate(url:)` (per brief §11.4 / US-SAFE-3).
7. Every mutating action is wrapped by `Safety/AuthorizationGate` which consults the `RiskClass` ↔ gate table (per brief §11.2 / US-SAFE-4).

**Stable type contracts (full list in §7 below).** `PlannerProtocol`, `RoutineStore`, `RoutineResolver`, `InputValidator`, `PlanValidator`, `RawPlan`, `ValidatedPlan`, `PlanStep`, `Action`, `RiskClass`, `SafetyVerdict`, `EnvelopedContent`, `URLPolicy`, `ExecutorLane`, `LaneResult`, `AuthorizationGate`, `ConfirmGate`, `PermissionsManaging`, `IdentityStore`, `SettingsStore`, `SandboxRunner`, `WebAdapter`, `AXAdapter`, `AppleScriptAdapter`, `PaneController`.

---

## 3. File-level inventory by phase

Conventions: `[new]` = create, `[mod]` = modify. Test files mirror source paths under `SingularityTests/`.

### Phase 0 — Shell skeleton

- `Singularity.xcodeproj/project.pbxproj` `[new]` — single app target, Swift 6, macOS 14, no SPM deps.
- `Singularity/App/SingularityApp.swift` `[new]` — `@main` SwiftUI `App`, sets `ActivationPolicy.accessory`, owns the panel.
- `Singularity/App/AppDelegate.swift` `[new]` — `NSApplicationDelegate`, lifecycle hooks, installs the hotkey, owns the `ShellWindowController`.
- `Singularity/App/Hotkey/HotkeyMonitor.swift` `[new]` — Carbon `RegisterEventHotKey` wrapper (per brief §3).
- `Singularity/App/Hotkey/KeyCombo.swift` `[new]` — `Codable` struct for key + modifier shape; basis for Settings rebinding later.
- `Singularity/Shell/ShellWindowController.swift` `[new]` — owns the `ShellPanel`, focus dance, screen-of-cursor selection (per brief §2).
- `Singularity/Shell/ShellPanel.swift` `[new]` — `NSPanel` subclass, `.nonactivatingPanel`, level `.mainMenu + 1`, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- `Singularity/Shell/ShellRootView.swift` `[new]` — SwiftUI root: log strip on top, compositor in middle, command input at bottom.
- `Singularity/Shell/CommandInput.swift` `[new]` — single-line input, auto-focus, submit on Return, Esc handling, 4 KB cap (cap enforcement lives here in Phase 0; credential scanner arrives Phase 2).
- `Singularity/Shell/SessionLog.swift` `[new]` — `@Observable` in-memory log model, cleared on dismiss (per US-S-3).
- `Singularity/Shell/SessionLogView.swift` `[new]` — scrollable view of the log.
- `Singularity/Compositor/Pane.swift` `[new]` — value type describing a pane.
- `Singularity/Compositor/PaneContainerView.swift` `[new]` — wraps a pane with a close affordance.
- `Singularity/Compositor/Compositor.swift` `[new]` — `@Observable`, manages the pane list, add/remove.
- `Singularity/Compositor/CompositorView.swift` `[new]` — tiling layout (2/3/4-pane variants per US-S-4).
- `Singularity/Compositor/PlaceholderPane.swift` `[new]` — empty-state pane for "no panes yet" so Phase 0 can demo add/remove.
- `Singularity/Info.plist` `[new]` — bundle ID, `LSUIElement` true (accessory), placeholder usage strings (filled per phase).
- `.swiftlint.yml` `[new]` — project lint config.
- `.swift-format` `[new]` — project format config.
- `SingularityTests/SingularityTests.swift` `[new]` — Swift Testing entry, smoke test.
- Mirrored test files for each new source file above.

### Phase 1 — Hero command, hardcoded

- `Singularity/Executor/Web/WebPaneController.swift` `[new]` — owns a `WKWebView`, attaches nav delegate + adapter, lives in a `Pane`.
- `Singularity/Executor/Web/WebView+Helpers.swift` `[new]` — `waitForSelector(selector, timeout)` JS helper, `callAsyncJavaScript` bridge.
- `Singularity/Executor/Web/AllowlistNavigationDelegate.swift` `[new]` — `WKNavigationDelegate` that defers to `URLPolicy.evaluate` (Phase 1 version is YouTube/googlevideo only).
- `Singularity/Adapters/Web/YouTubeAdapter.swift` `[new]` — `allowedHosts`, `WKContentWorld` name `"singularity"`, `playNewestForChannel(_:)` JS hook.
- `Singularity/Adapters/Web/WebAdapter.swift` `[new]` — `WebAdapter` protocol shared by all Phase 3+ adapters.
- `Singularity/Planner/StringMatcherPlanner.swift` `[new]` — Phase 1 stand-in planner conforming to `PlannerProtocol`; recognizes the hero phrase.
- `Singularity/Planner/PlannerProtocol.swift` `[new]` — protocol shared between Phase 1 string-matcher and Phase 2 Ollama planner.
- `Singularity/Planner/RawPlan.swift` `[new]` — value type for a decoded but unvalidated plan.
- `Singularity/Planner/PlanStep.swift` `[new]` — single step; the `Action` enum lives in `Executor/Actions.swift` so Planner and Executor share it.
- `Singularity/Executor/Actions.swift` `[new]` — `Action` enum (`open_url`, later `run_script`, `ax_action`, `applescript`, `file_op`, `run_shell`).
- `Singularity/Executor/ExecutorRouter.swift` `[new]` — initial version accepts a Phase-1 `ValidatedPlan` (constructed by a Phase-1 stub).
- `Singularity/Safety/ValidatedPlan.swift` `[new]` — value type with file-private init and stub Phase-1 factory.
- `Singularity/Safety/SafetyVerdict.swift` `[new]` — `enum SafetyVerdict { case allow, deny(reason) }` with Phase 1 always-allow stub.
- `Singularity/Shell/CommandPipeline.swift` `[new]` — orchestrates input → planner → validator-stub → executor; replaced with real validator in Phase 5.
- Mirrored test files.

### Phase 2 — Intent engine

- `Singularity/Planner/OllamaClient.swift` `[new]` — async HTTP client to `localhost:11434`, `/api/chat` + `/api/tags`.
- `Singularity/Planner/OllamaPlanner.swift` `[new]` — `PlannerProtocol` impl wrapping `OllamaClient` with strict `format: <JSONSchema>` and validate→repair-once→fail-loud loop (per brief §1 / US-P-2).
- `Singularity/Planner/PlanSchema.swift` `[new]` — JSON Schema as a `Codable` Swift value + the matching `RawPlan` extension.
- `Singularity/Planner/PlannerError.swift` `[new]` — typed errors (`.unparseable`, `.unreachable`, `.timeout`, `.transport`).
- `Singularity/Planner/SystemPrompt.swift` `[new]` — string constant containing the system prompt; loaded from `Resources/system-prompt.md`.
- `Singularity/Resources/system-prompt.md` `[new]` — the system prompt text, including the "untrusted content envelope" directive.
- `Singularity/Resources/plan-schema.json` `[new]` — JSON Schema as a static asset for reference / tooling.
- `Singularity/Safety/InputValidator.swift` `[new]` — Unicode normalization, credential scanner, cap, rate limit (per brief §11.1 / US-SAFE-1). Turns on in Phase 2 so nothing reaches Ollama unprotected.
- `Singularity/Safety/SecretPatterns.swift` `[new]` — regex bank for AWS/GitHub/OpenAI/Slack/Stripe/Google/Luhn/SSN.
- `Singularity/Safety/RateLimiter.swift` `[new]` — in-process token bucket (20/min, 200/hr).
- `Singularity/Shell/CommandPipeline.swift` `[mod]` — swap `StringMatcherPlanner` for `OllamaPlanner` behind the protocol; insert `InputValidator` ahead of the planner.
- `Singularity/Settings/SettingsStore.swift` `[new]` — early skeleton holding the Phase 2 planner-related settings (`ollamaBaseURL`, `plannerModel`, `plannerTimeoutSec`) so the Phase 7 Settings UI can later read from a stable store.
- Mirrored test files (including golden tests for varied phrasings → equivalent plans).

### Phase 3 — Router and easy lanes

- `Singularity/Executor/ExecutorRouter.swift` `[mod]` — real lane dispatch by `Action`-type; first-match-wins waterfall.
- `Singularity/Executor/ExecutorLane.swift` `[new]` — `protocol ExecutorLane { func canHandle(_:) -> Bool; func execute(_:) async throws -> LaneResult }`.
- `Singularity/Executor/LaneResult.swift` `[new]` — value type for what a lane returns (text result, pane reference, etc.).
- `Singularity/Executor/URLScheme/URLSchemeLane.swift` `[new]` — lane 1, dispatches `open_url` via `NSWorkspace.shared.open`.
- `Singularity/Executor/Web/WebLane.swift` `[new]` — lane 2 dispatcher, picks the right `WebAdapter` per host, manages its `WebPaneController`.
- `Singularity/Executor/Web/AdapterRegistry.swift` `[new]` — discovers all `WebAdapter`s at app start.
- `Singularity/Adapters/Web/YouTubeAdapter.swift` `[mod]` — generalize beyond hero; declare `allowsDownloads: false`.
- `Singularity/Adapters/Web/GmailAdapter.swift` `[new]` — Phase 3 second web adapter (read-only operations only at this stage).
- `Singularity/Adapters/Web/WebAdapter.swift` `[mod]` — add `dataStoreIdentifier: UUID`, `allowsDownloads: Bool`, `contentWorldName: String`.
- `Singularity/Safety/AllowedDomains.swift` `[new]` — read-only registry that unions all adapter `allowedHosts` at app start (per brief §11.4 / US-SAFE-3).
- `Singularity/Safety/URLPolicy.swift` `[new]` — single `evaluate(url:)` decision point; Phase 3 version is allowlist + HTTPS + userinfo checks. NSFW layer arrives Phase 5.
- `Singularity/Executor/Web/AllowlistNavigationDelegate.swift` `[mod]` — defer to the generalized `URLPolicy.evaluate`.
- `Singularity/Executor/Web/AllowlistDownloadDelegate.swift` `[new]` — `WKDownloadDelegate`, defaults deny (per brief §11.4 / US-E-2).
- `Singularity/Safety/SafetyLog.swift` `[new]` — `os.Logger` scaffold (per brief §11.7 / US-SAFE-8). Phase 3 adds the API surface; richer call-sites land in Phase 5.
- Mirrored test files.

### Phase 4 — Native app control

- `Singularity/Executor/Accessibility/AXElement.swift` `[new]` — thin Swift wrapper around `AXUIElement`.
- `Singularity/Executor/Accessibility/AXApplication.swift` `[new]` — root-by-pid, cached.
- `Singularity/Executor/Accessibility/AXObservation.swift` `[new]` — `AXObserver` bridged to `AsyncStream`.
- `Singularity/Executor/Accessibility/AXErrors.swift` `[new]` — typed errors mapping `AXError`.
- `Singularity/Executor/Accessibility/AXLane.swift` `[new]` — lane 3 dispatcher.
- `Singularity/Adapters/Accessibility/AXAdapter.swift` `[new]` — adapter protocol for AX (bundle ID + actions).
- `Singularity/Adapters/Accessibility/SpotifyAXAdapter.swift` `[new]` — Spotify native control (play/pause/next).
- `Singularity/Adapters/Accessibility/MailAXAdapter.swift` `[new]` — read latest mail subject/body (still wrapped via `UntrustedContentFilter` once that arrives in Phase 5; Phase 4 leaves a TODO comment marker checked by the Phase 5 tasks).
- `Singularity/Permissions/PermissionsManager.swift` `[new]` — initial version exposes Accessibility state from `AXIsProcessTrusted()`; expanded in Phase 7.
- `Singularity/Permissions/SystemSettingsLinks.swift` `[new]` — URL constants for the three TCC panes.
- `Singularity/Settings/Tabs/AdvancedTabView.swift` `[new]` — minimal Phase 4 surface: `axdump` invoker (per brief §5 / US-SET-7 component) so adapter authors can use it. Rest of Advanced lands in Phase 7.
- `Singularity/Executor/Accessibility/AXDump.swift` `[new]` — utility that prints the AX tree of a target bundle ID into the session log.
- Mirrored test files (mostly integration-style; AX is hard to unit-test pure).

### Phase 5 — Safety pipeline

- `Singularity/Safety/PlanValidator.swift` `[new]` — replaces the Phase-1 stub; sole producer of `ValidatedPlan` (per US-SAFE-2 / brief §11.3).
- `Singularity/Safety/ValidatedPlan.swift` `[mod]` — make init file-private to `PlanValidator`; rip out the Phase 1 stub.
- `Singularity/Safety/PlanRejection.swift` `[new]` — enum of rejection reasons + structured payload.
- `Singularity/Safety/RiskClass.swift` `[new]` — `enum RiskClass { case read, reversible, destructive, spend }` plus default mapping.
- `Singularity/Safety/AuthorizationGate.swift` `[new]` — `LAContext.evaluatePolicy(.deviceOwnerAuthentication, …)`; 30s grace cache cleared on dismiss (per brief §11.2 / US-SAFE-4).
- `Singularity/Safety/ConfirmGate.swift` `[new]` — modal-inline preview UI binding (per US-SAFE-5).
- `Singularity/Safety/ConfirmGateView.swift` `[new]` — SwiftUI sheet for previews.
- `Singularity/Safety/UntrustedContentFilter.swift` `[new]` — `wrap(content:source:)` and `scan(content:)`; `EnvelopedContent` type (per brief §11.6 / US-SAFE-6).
- `Singularity/Safety/EnvelopedContent.swift` `[new]` — opaque type guarded by `UntrustedContentFilter`.
- `Singularity/Safety/ContentRing.swift` `[new]` — ring buffer of recent untrusted-content hashes for cross-context contamination check.
- `Singularity/Safety/NSFWBlocklist.swift` `[new]` — loads `Resources/nsfw-blocklist.txt` into `Set<String>`.
- `Singularity/Resources/nsfw-blocklist.txt` `[new]` — curated from StevenBlack hosts (per brief §12.2 / US-NSFW-1). Bundled-static-only.
- `Scripts/refresh-nsfw-list.sh` `[new]` — Makefile-style helper for maintainers to refresh the bundled list (per spec §6 #7).
- `Singularity/Safety/URLPolicy.swift` `[mod]` — fold NSFW check ahead of allowlist check.
- `Singularity/Safety/PanicController.swift` `[new]` — `abort` parsing + double-Esc handling + `Task.cancel()` propagation (per US-SAFE-7).
- `Singularity/Shell/CommandInput.swift` `[mod]` — wire double-Esc detection + `abort` recognition into `PanicController`.
- `Singularity/Shell/CommandPipeline.swift` `[mod]` — replace stub validator with real `PlanValidator`; insert `AuthorizationGate` and `ConfirmGate` ahead of `ExecutorRouter.dispatch`.
- `Singularity/Safety/SafetyLog.swift` `[mod]` — fill out the API surface (`inputBlocked`, `planRejected`, `urlDenied`, `authFailed`, `untrustedHeuristicFired`, `panicCancelled`).
- `Singularity/Routines/Routine.swift` `[new]` — `Codable` model (`name`, `steps`, `createdAt`, `updatedAt`).
- `Singularity/Routines/RoutineStore.swift` `[new]` — actor; load/save atomically to `~/Library/Application Support/Singularity/routines.json` (per spec §6 #13). Storage only — no UI here; that lands in Phase 7.
- `Singularity/Routines/RoutineStorageError.swift` `[new]` — typed errors.
- `Singularity/Adapters/Web/AmazonAdapter.swift` `[new]` — written here (not Phase 3) because its two-stop Touch ID + confirm flow depends on `AuthorizationGate` and `ConfirmGate` (per US-SAFE-5 / brief §11.2).
- `Singularity/Settings/Tabs/SafetyTabView.swift` `[new]` — NSFW toggle, grace seconds, panic phrase, allowlist viewer. Wired here because Phase 5 is when the settings *exist*.
- `Singularity/Settings/SettingsStore.swift` `[mod]` — add `nsfwFilterEnabled`, `touchIDGraceSeconds`, `panicPhrase`.
- Mirrored test files. Safety-pipeline tests are extensive — see §6.

### Phase 6 — System and file lanes

- `Singularity/Executor/AppleScript/AppleScriptLane.swift` `[new]` — lane 4 dispatcher.
- `Singularity/Executor/AppleScript/CompiledScriptCache.swift` `[new]` — `NSAppleScript` cache (per brief §6 / US-E-4).
- `Singularity/Adapters/AppleScript/AppleScriptAdapter.swift` `[new]` — adapter protocol.
- `Singularity/Adapters/AppleScript/MailAppleScriptAdapter.swift` `[new]` — read/draft/send mail.
- `Singularity/Adapters/AppleScript/CalendarAppleScriptAdapter.swift` `[new]` — events.
- `Singularity/Adapters/AppleScript/MusicAppleScriptAdapter.swift` `[new]` — playback control.
- `Singularity/Adapters/AppleScript/FinderAppleScriptAdapter.swift` `[new]` — selection / reveal.
- `Singularity/Adapters/AppleScript/RemindersAppleScriptAdapter.swift` `[new]` — lists.
- `Singularity/Adapters/AppleScript/NotesAppleScriptAdapter.swift` `[new]` — read/create notes.
- `Singularity/Adapters/AppleScript/SafariAppleScriptAdapter.swift` `[new]` — tabs.
- `Singularity/Executor/Files/FilesLane.swift` `[new]` — lane 5 dispatcher.
- `Singularity/Executor/Files/FileOperations.swift` `[new]` — move/copy/list/trash via `FileManager`.
- `Singularity/Executor/Files/StagingStore.swift` `[new]` — copy-to-staging + retention of N=10 (per brief §7 / US-E-5).
- `Singularity/Executor/Files/SandboxRunner.swift` `[new]` — `sandbox-exec` wrapper; profile + denials (per brief §8).
- `Singularity/Executor/Files/SandboxProfile.sb` `[new]` — sandbox profile: deny network, deny writes outside scope, deny process spawn except whitelist.
- `Singularity/Executor/Files/ShellValidator.swift` `[new]` — static rules: rejects `curl|sh`, base64-to-bash, `..` escape, TCC-path access without declared intent.
- `Singularity/Safety/PlanValidator.swift` `[mod]` — wire in shell + file-path validation (`ShellValidator`, `FilePathValidator`) and action-graph taint check.
- `Singularity/Safety/FilePathValidator.swift` `[new]` — resolves symlinks, checks scope, rejects escapes.
- `Singularity/Info.plist` `[mod]` — add `NSAppleEventsUsageDescription` (per brief §6 / US-E-4).
- `Singularity.entitlements` `[mod]` — add `com.apple.security.automation.apple-events` (per brief §6).
- Mirrored test files.

### Phase 7 — Daily-driver polish

- `Singularity/Identity/AppleIDSignIn.swift` `[new]` — `SignInWithAppleButton` wiring (per brief §12.1 / US-ID-1).
- `Singularity/Identity/IdentityStore.swift` `[new]` — Keychain read/write of `IdentityRecord`.
- `Singularity/Identity/IdentityRecord.swift` `[new]` — `Codable` payload.
- `Singularity/Identity/CredentialStateChecker.swift` `[new]` — launch-time `getCredentialState(forUserID:)` (per US-ID-2).
- `Singularity/Permissions/PermissionsManager.swift` `[mod]` — add Automation cache + FDA probe + 2s polling-when-foregrounded.
- `Singularity/Permissions/FirstRunFlow.swift` `[new]` — onboarding sequence: permissions checklist + Sign in with Apple step (skip-able).
- `Singularity/Permissions/FirstRunView.swift` `[new]` — SwiftUI view for above.
- `Singularity/Settings/SettingsScene.swift` `[new]` — `Settings { … }` SwiftUI scene with 7-tab `TabView`.
- `Singularity/Settings/Tabs/GeneralTabView.swift` `[new]` — hotkey rebind, launch-at-login (`SMAppService`), appearance.
- `Singularity/Settings/Tabs/PlannerTabView.swift` `[new]` — model picker (from `/api/tags`), URL, timeout, Apply button.
- `Singularity/Settings/Tabs/RoutinesTabView.swift` `[new]` — list, detail editor, delete confirm, reveal-in-Finder footer (per US-SET-4).
- `Singularity/Settings/Tabs/PermissionsTabView.swift` `[new]` — three-section status + deep links (per US-SET-5).
- `Singularity/Settings/Tabs/AccountTabView.swift` `[new]` — avatar/name/email/about/sign-out (per US-ACC-1).
- `Singularity/Settings/Tabs/AdvancedTabView.swift` `[mod]` — add log viewer (`OSLogStore`), `/safety log` invoker, Factory Reset.
- `Singularity/Settings/FactoryReset.swift` `[new]` — orchestrates deletion of Keychain, UserDefaults, per-adapter data stores, routines.json.
- `Singularity/Settings/HotkeyRecorder.swift` `[new]` — SwiftUI key-recorder field.
- `Singularity/Settings/LaunchAtLogin.swift` `[new]` — `SMAppService` wrapper.
- `Singularity/Routines/RoutineResolver.swift` `[new]` — bare-name + `run NAME` recognition; expansion ordering ahead of planner (per US-RT-2 / US-RT-6).
- `Singularity/Routines/RoutineParser.swift` `[new]` — parses `routine NAME = step1; step2` syntax + reserved-word check (per US-RT-1).
- `Singularity/Routines/RoutineCommandHandler.swift` `[new]` — handles `routine …`, `routines`, `routine delete NAME` inline commands (per US-RT-3 / US-RT-4 / US-RT-5).
- `Singularity/Shell/CommandPipeline.swift` `[mod]` — insert `RoutineResolver` between `InputValidator` and `OllamaPlanner`.
- `Singularity/Resources/PrivacyPolicy.url` `[new]` — link target for the Account "privacy policy" button.
- `Singularity/Info.plist` `[mod]` — add `NSFaceIDUsageDescription`.
- Mirrored test files.

---

## 4. Task checklist

Atomic, ordered, traceable. Each task is small enough for one focused sitting. Mark `[x]` only when the acceptance check passes.

### Phase 0 — Shell skeleton

- [x] **T-P0-01: Bootstrap Xcode project**
  *Advances: (infra)*
  *Per brief: §10 (prior art for project structure)*
  *Depends on: —*
  *Acceptance check:* `xcodebuild -scheme Singularity build` succeeds on a clean checkout; `xcodebuild test -scheme Singularity -destination 'platform=macOS'` runs the empty test target green.
  *Notes:* Single app target named `Singularity`, Swift 6, macOS 14 deployment, Apple Silicon. `LSUIElement = YES` in `Info.plist` (accessory app, no Dock icon). No SPM dependencies. Add `.swiftlint.yml` and `.swift-format` configs with defaults; CI step is `swiftlint && swift-format lint -r Singularity SingularityTests`.

- [x] **T-P0-02: SwiftUI App entry point with accessory activation policy** *(follow-up T-P0-13 covers the LSUIElement Info.plist setting that requires the Xcode GUI)*
  *Advances: US-S-1 (infra)*
  *Per brief: §2 (`ActivationPolicy.accessory`)*
  *Depends on: T-P0-01*
  *Acceptance check:* App launches with no Dock icon and no menu bar; `NSApp.activationPolicy() == .accessory` verified in a unit test.
  *Notes:* `@main struct SingularityApp: App` with an empty `Settings { … }` placeholder (real tabs land in Phase 7). `AppDelegate` set via `@NSApplicationDelegateAdaptor`.

- [x] **T-P0-03: Hotkey wrapper using Carbon `RegisterEventHotKey`**
  *Advances: US-S-1*
  *Per brief: §3*
  *Depends on: T-P0-02*
  *Acceptance check:* Unit test verifies `HotkeyMonitor.install(keyCode:modifiers:)` returns a non-nil token and `uninstall` returns no error. Manual: press `⌥Space` from any foreground app and a logged callback fires (verified by an `os.Logger` print at this stage).
  *Notes:* No SPM dep for hotkey work — implement the Carbon wrapper inline as outlined in brief §3 (DivineDominion/Magnet shape, no vendored code). No Input Monitoring permission required.

- [x] **T-P0-04: `KeyCombo` `Codable` value type**
  *Advances: US-S-1, US-SET-1 (foundation for rebind)*
  *Per brief: §12.4*
  *Depends on: T-P0-03*
  *Acceptance check:* Round-trip JSON encode/decode test of `KeyCombo(keyCode: 49, modifiers: [.option])` passes; matches the default `⌥Space`.

- [x] **T-P0-05: `ShellPanel` NSPanel subclass**
  *Advances: US-S-1*
  *Per brief: §2*
  *Depends on: T-P0-02*
  *Acceptance check:* Unit test that constructs a `ShellPanel`, asserts `level == NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))` or `NSWindow.Level.mainMenu.rawValue + 1`, `collectionBehavior` contains `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, and `styleMask.contains(.nonactivatingPanel)`.

- [x] **T-P0-06: `ShellWindowController` with screen-of-cursor selection**
  *Advances: US-S-1*
  *Per brief: §2*
  *Depends on: T-P0-05*
  *Acceptance check:* Manual: hotkey shows the panel covering the screen that contains the cursor; works under Stage Manager on and off; pressing the hotkey again hides the panel and returns focus to the previous app (verified by `NSApp.hide(nil)` after `orderOut`).
  *Notes:* Sets `NSApp.presentationOptions = [.hideMenuBar, .hideDock]` while visible, restores on hide. Activates with `NSApp.activate(ignoringOtherApps: true)` then `window.makeKeyAndOrderFront(nil)`.

- [x] **T-P0-07: `ShellRootView` SwiftUI scaffolding**
  *Advances: US-S-1*
  *Per brief: §2*
  *Depends on: T-P0-06*
  *Acceptance check:* Snapshot or layout test: log strip on top (empty), compositor in middle (empty), command input at bottom (auto-focused). No real behavior yet.

- [x] **T-P0-08: `CommandInput` view with auto-focus, Return, Esc, 4 KB cap**
  *Advances: US-S-2*
  *Per brief: §11.1 (4 KB cap)*
  *Depends on: T-P0-07*
  *Acceptance check:* Test: typing 4097 characters truncates to 4096 and emits one "input truncated to 4 KB" line into the session log; Return submits and clears; Esc with empty input dismisses, Esc with non-empty clears.
  *Notes:* Credential scanner and panic phrase wiring land in Phase 2 / Phase 5 respectively. This task only enforces the cap and the basic key handling.

- [ ] **T-P0-09: `SessionLog` model and view**
  *Advances: US-S-3*
  *Per brief: §11.7 (logging discipline up front)*
  *Depends on: T-P0-07*
  *Acceptance check:* Test: appending entries appends to the in-memory list; calling `clear()` empties it; the view renders entries in order; reopening the shell shows an empty log (verified by clearing on `ShellWindowController.hide`).

- [ ] **T-P0-10: `Compositor` model and `CompositorView` (1/2/3/4-pane layouts)**
  *Advances: US-S-4*
  *Per brief: §2 (multi-pane handling)*
  *Depends on: T-P0-07*
  *Acceptance check:* Test: adding 1, 2, 3, 4 `PlaceholderPane` instances renders them tiled; each has a visible close button; closing reduces the count.

- [ ] **T-P0-11: Dismiss-shell disposes panes**
  *Advances: US-S-4*
  *Per brief: §2*
  *Depends on: T-P0-10, T-P0-06*
  *Acceptance check:* Manual + integration test: open the shell, add 2 placeholder panes via a debug stub, dismiss; reopen — compositor is empty.

- [ ] **T-P0-12: Phase 0 integration test — summon, type, log, dismiss**
  *Advances: US-S-1, US-S-2, US-S-3, US-S-4*
  *Per brief: §2, §3*
  *Depends on: T-P0-08, T-P0-09, T-P0-10, T-P0-11*
  *Acceptance check:* XCUITest or scripted manual checklist: launch the app, hotkey, type `hello`, Return (placeholder logs "command not yet handled"), Esc, hotkey again, log is empty.

- [x] **T-P0-13 [USER]: Set `LSUIElement = YES` in the Singularity target's Info build settings**
  *Advances: US-S-1 (cosmetic completion)*
  *Per brief: §2*
  *Depends on: T-P0-02*
  *Acceptance check:* Launch the built `.app`; no Dock icon flashes at any point. Confirm with `defaults read .../Info.plist LSUIElement` returns `1` in the built bundle.
  *Notes:* Deferred from T-P0-02. `.accessory` set in `AppDelegate.applicationDidFinishLaunching` already hides the Dock icon after launch, but a brief flash occurs at launch. Modern SwiftUI Xcode projects auto-generate Info.plist from build settings; setting `LSUIElement` cleanly requires the Xcode GUI (Target → Info tab → add row "Application is agent (UIElement)" = YES). User-action task because editing `project.pbxproj` by hand is off-limits per CLAUDE.md.

### Phase 1 — Hero command, hardcoded

- [ ] **T-P1-01: `Action` enum + `PlanStep` + `RawPlan` types**
  *Advances: US-P-1 (foundation)*
  *Per brief: §1*
  *Depends on: T-P0-12*
  *Acceptance check:* `Codable` round-trip test for a minimal `RawPlan` with one `open_url`-shape step. Type lives under `Executor/Actions.swift` and is shared by Planner.

- [ ] **T-P1-02: Stub `ValidatedPlan` with Phase-1 factory + `SafetyVerdict.allow` stub**
  *Advances: US-SAFE-2 (placeholder)*
  *Per brief: §11.3*
  *Depends on: T-P1-01*
  *Acceptance check:* Test asserts `ValidatedPlan` cannot be constructed from `RawPlan` directly; only the Phase-1 factory `ValidatedPlan.phase1Allow(_:)` (clearly marked TODO-remove-in-Phase-5) returns one. This is the architectural seed for the type-level gate.

- [ ] **T-P1-03: `PlannerProtocol` and `StringMatcherPlanner`**
  *Advances: US-P-1 (Phase 1 stand-in)*
  *Per brief: §1*
  *Depends on: T-P1-01*
  *Acceptance check:* Test: `play mrbeast newest video` resolves to a `RawPlan` with one step `open_url` for `https://www.youtube.com/@MrBeast/videos` plus a follow-up `run_script` step naming the YouTube adapter hook. Unrecognized inputs return `nil` (Phase 1 has no other phrases).

- [ ] **T-P1-04: `WebAdapter` protocol + `YouTubeAdapter` Phase 1 hook**
  *Advances: US-E-2*
  *Per brief: §4*
  *Depends on: T-P1-01*
  *Acceptance check:* Adapter exposes `allowedHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "googlevideo.com"]`, `contentWorldName = "singularity"`, and `playNewestForChannel(_:)` JS string that uses a `MutationObserver`-based `waitForSelector` and clicks the first video link.

- [ ] **T-P1-05: `AllowlistNavigationDelegate` (Phase 1 hardcoded for YouTube)**
  *Advances: US-SAFE-3 (partial), US-E-2*
  *Per brief: §11.4*
  *Depends on: T-P1-04*
  *Acceptance check:* Test: navigation to a host not in the YouTube adapter's `allowedHosts` returns `.cancel`; navigation to `https://www.youtube.com/...` returns `.allow`. The full `URLPolicy` generalization happens in Phase 3.

- [ ] **T-P1-06: `WebView+Helpers.waitForSelector` JS helper**
  *Advances: US-E-2*
  *Per brief: §4*
  *Depends on: T-P1-04*
  *Acceptance check:* Test (with `WKWebView` in a hidden window) loads a local HTML fixture, waits for a selector that appears after a 200ms timer, and resolves; a non-existing selector with 1s timeout throws.

- [ ] **T-P1-07: `WebPaneController` builds a `WKWebView` with per-adapter data store and content world**
  *Advances: US-E-2*
  *Per brief: §11.5 (per-adapter `WKWebsiteDataStore`)*
  *Depends on: T-P1-06*
  *Acceptance check:* Test: creating a `WebPaneController(adapter: youtube)` produces a `WKWebView` whose configuration's `websiteDataStore.identifier` equals the YouTube adapter's UUID; the nav delegate is the `AllowlistNavigationDelegate`; downloads are denied.

- [ ] **T-P1-08: Wire `WebPaneController` into a compositor `Pane`**
  *Advances: US-S-4, US-E-2*
  *Depends on: T-P1-07, T-P0-10*
  *Acceptance check:* Test: adding a `Pane` of type `.web(WebPaneController)` tiles it; closing the pane releases the `WKWebView`; dismissing the shell disposes the pane.

- [ ] **T-P1-09: `ExecutorRouter` Phase-1 wiring (dispatches the hero `ValidatedPlan` only)**
  *Advances: US-E-2 (constrained)*
  *Depends on: T-P1-02, T-P1-08*
  *Acceptance check:* Test: given a `ValidatedPlan` containing the hero step list, the router opens a `WebPaneController` for YouTube and triggers the adapter's `playNewestForChannel("MrBeast")` after `didFinish`.

- [ ] **T-P1-10: `CommandPipeline` wires input → string-matcher → stub-validator → router**
  *Advances: US-P-1 (Phase 1 path)*
  *Depends on: T-P1-03, T-P1-09*
  *Acceptance check:* Integration test: typing `play mrbeast newest video` and pressing Return ends with a YouTube pane in the compositor and the log showing the command + "playing newest MrBeast video".

- [ ] **T-P1-11: Hero acceptance test (manual)**
  *Advances: §5 (hero)*
  *Per brief: §2, §3, §4, §11.4, §11.5*
  *Depends on: T-P1-10*
  *Acceptance check:* On an Apple Silicon Mac (M-series, 16 GB), cold-launch to playing video in under 5 seconds. YouTube login persists across two cold launches (proves per-adapter persistent `WKWebsiteDataStore`). Allowlist denies any non-YouTube/googlevideo navigation. Dismissing the shell stops playback.

### Phase 2 — Intent engine

- [ ] **T-P2-01 [USER]: Install Ollama and pull the default model**
  *Advances: US-P-1, US-P-3*
  *Per brief: §1*
  *Depends on: T-P1-11*
  *Acceptance check:* `curl http://localhost:11434/api/tags` returns at least one model. The user has run `ollama pull qwen2.5-coder:7b-instruct-q4_K_M` (per spec §6 #10). Stop here and wait for the user to confirm.

- [ ] **T-P2-02: `OllamaClient` HTTP wrapper**
  *Advances: US-P-1, US-P-3*
  *Per brief: §1*
  *Depends on: T-P2-01*
  *Acceptance check:* Async test (hits real localhost Ollama): `await client.tags()` returns a non-empty array; `await client.chat(model:, messages:, format: schema, temperature: 0)` returns a `Codable`-decodable response payload. Timeout default 30s, configurable.

- [ ] **T-P2-03: `PlanSchema` + `SystemPrompt` resources**
  *Advances: US-P-1*
  *Per brief: §1, §11.6 (envelope directive in prompt)*
  *Depends on: T-P2-02*
  *Acceptance check:* `plan-schema.json` validates with a standalone JSON Schema validator (manual one-off check); `system-prompt.md` includes the untrusted-content-envelope directive verbatim from spec §6 (US-SAFE-6).

- [ ] **T-P2-04: `OllamaPlanner` with validate→repair-once→fail-loud loop**
  *Advances: US-P-1, US-P-2*
  *Per brief: §1*
  *Depends on: T-P2-03*
  *Acceptance check:* Unit tests (Ollama mocked via injected `OllamaClientProtocol`): (a) valid response → `RawPlan` returned; (b) first response fails decode → second request includes the failing output and the decode error; (c) second response also fails → throws `PlannerError.unparseable`. Hash of malformed output is logged at `.private` (verified via a test logger).

- [ ] **T-P2-05: Golden tests for varied-phrasing equivalence**
  *Advances: US-P-1*
  *Per brief: §1*
  *Depends on: T-P2-04*
  *Acceptance check:* Test runs against a recorded fixture set (or live Ollama with a marker) covering `play mrbeast newest video`, `open youtube and play the newest mrbeast`, `play the latest mrbeast video`. All resolve to functionally equivalent plans (same action types, same URL host, same adapter call).

- [ ] **T-P2-06: `SecretPatterns` regex bank**
  *Advances: US-SAFE-1*
  *Per brief: §11.1*
  *Depends on: T-P2-01*
  *Acceptance check:* Table-driven tests cover at least one positive per category (AWS, GitHub PAT, OpenAI `sk-`, Slack `xox`, Stripe `sk_live_`, Google `AIza`, Luhn-valid PAN, US SSN) and three near-misses per category (ensure no false positives on innocuous strings).

- [ ] **T-P2-07: `RateLimiter` token bucket (20/min, 200/hr)**
  *Advances: US-SAFE-1*
  *Per brief: §11.1*
  *Depends on: T-P2-01*
  *Acceptance check:* Test: 20 calls within a minute succeed; the 21st returns `.rateLimited`; after the minute window slides, calls succeed again. Same for the hourly bucket.

- [ ] **T-P2-08: `InputValidator` end-to-end (normalize → scan → cap → submit)**
  *Advances: US-SAFE-1, US-S-2 (cap)*
  *Per brief: §11.1*
  *Depends on: T-P2-06, T-P2-07*
  *Acceptance check:* Tests: zero-width chars are stripped; bidi controls are stripped; control chars except `\n`/`\t` are stripped; an AWS-key-shaped input is dropped, the raw string is *not* in any log entry, and the session log shows "I dropped that — it contained what looked like an AWS key. Retype without the key."; password-shaped strings produce a warn-only log line; over-cap input truncates with a "truncated to 4 KB" line.

- [ ] **T-P2-09: Wire `OllamaPlanner` into `CommandPipeline` behind `PlannerProtocol`**
  *Advances: US-P-1*
  *Per brief: §1*
  *Depends on: T-P2-04, T-P2-08*
  *Acceptance check:* Integration test: with Ollama running, typing the hero command still works end-to-end (regression check); typing `open google` does not work because no adapter handles it (acceptable — Phase 3 adds breadth) but the planner returns a valid `RawPlan` with one `open_url` step.

- [ ] **T-P2-10: `SettingsStore` skeleton for planner settings**
  *Advances: US-P-3, US-SET-2 (foundation)*
  *Per brief: §12.4*
  *Depends on: T-P2-04*
  *Acceptance check:* `@Observable` store exposes `ollamaBaseURL`, `plannerModel`, `plannerTimeoutSec` with defaults `http://localhost:11434`, `qwen2.5-coder:7b-instruct-q4_K_M`, `30`. Tests: changing a value persists to `UserDefaults` and survives restart (mocked via `UserDefaults(suiteName:)`). No UI yet; that lands in Phase 7.

### Phase 3 — Router and easy lanes

- [ ] **T-P3-01: `ExecutorLane` protocol + `LaneResult`**
  *Advances: US-E-1, US-E-2 (generalization)*
  *Per brief: §10 (waterfall shape)*
  *Depends on: T-P2-09*
  *Acceptance check:* Protocol compiles; test double conforms and is callable from the router.

- [ ] **T-P3-02: Generalize `ExecutorRouter` to lane waterfall**
  *Advances: US-E-1, US-E-2*
  *Per brief: §10*
  *Depends on: T-P3-01*
  *Acceptance check:* Test: router with two registered fake lanes dispatches each step to the first lane whose `canHandle(_:)` returns true; if none match, returns `.unhandled` and the pipeline surfaces "I couldn't handle that step."

- [ ] **T-P3-03: `URLSchemeLane` (lane 1)**
  *Advances: US-E-1*
  *Per brief: §4*
  *Depends on: T-P3-02*
  *Acceptance check:* Test (mocking `NSWorkspace.open`): a plan step `open_url("spotify:track:xxx")` dispatches via `NSWorkspace.shared.open(_:)`; an HTTPS URL is rejected here (handled by the Web lane instead, unless an adapter explicitly declares lane-1 handling); an unregistered custom scheme is rejected by the validator (verified later in Phase 5).

- [ ] **T-P3-04: `WebAdapter` registry**
  *Advances: US-E-2*
  *Per brief: §4*
  *Depends on: T-P3-02*
  *Acceptance check:* Registry collects all `WebAdapter` instances declared in `Adapters/Web/`; `lookup(host:)` returns the right adapter for a host in its `allowedHosts`.

- [ ] **T-P3-05: `AllowedDomains` central registry (union of all adapter `allowedHosts`)**
  *Advances: US-SAFE-3*
  *Per brief: §11.4*
  *Depends on: T-P3-04*
  *Acceptance check:* Test: at app start, `AllowedDomains.all` equals the lower-cased union of every adapter's `allowedHosts`; `contains("WWW.YOUTUBE.COM")` returns true (case-insensitive); IDN host `xn--…` round-trips correctly.

- [ ] **T-P3-06: `URLPolicy.evaluate(url:)` (Phase 3 version: HTTPS + allowlist + userinfo)**
  *Advances: US-SAFE-3*
  *Per brief: §11.4*
  *Depends on: T-P3-05*
  *Acceptance check:* Tests: HTTPS off-list → deny; HTTP → deny; `https://user:pass@…` → deny; `data:` / `file://` / `javascript:` → deny; on-list HTTPS → allow. (NSFW check is layered in Phase 5.)

- [ ] **T-P3-07: Refactor `AllowlistNavigationDelegate` to delegate to `URLPolicy.evaluate`**
  *Advances: US-SAFE-3, US-E-2*
  *Per brief: §11.4*
  *Depends on: T-P3-06*
  *Acceptance check:* The Phase 1 hardcoded YouTube delegate is replaced by a generic delegate that consults `URLPolicy.evaluate`. Hero command still works (regression).

- [ ] **T-P3-08: `AllowlistDownloadDelegate` (default deny)**
  *Advances: US-E-2*
  *Per brief: §11.4*
  *Depends on: T-P3-07*
  *Acceptance check:* Test: any download attempt on a pane whose adapter has `allowsDownloads = false` is denied and logged; flipping a test-only adapter to `allowsDownloads = true` allows the download.

- [ ] **T-P3-09: Route `window.open`/`_blank` through the nav delegate**
  *Advances: US-E-2*
  *Per brief: §11.4*
  *Depends on: T-P3-07*
  *Acceptance check:* Test: a JS `window.open("https://allowed-host")` reuses the current pane (no new unparented window); `window.open("https://disallowed")` is denied. Verified with a local HTML fixture.

- [ ] **T-P3-10: `WebLane` dispatcher**
  *Advances: US-E-2*
  *Per brief: §4*
  *Depends on: T-P3-07, T-P3-04*
  *Acceptance check:* Test: a `RawPlan` step `open_url("https://www.youtube.com/...")` is dispatched to the WebLane, which picks `YouTubeAdapter`, builds a `WebPaneController`, tiles the pane.

- [ ] **T-P3-11: `GmailAdapter` (read-only ops in Phase 3)**
  *Advances: US-E-2*
  *Per brief: §4*
  *Depends on: T-P3-10*
  *Acceptance check:* Adapter has its own `WKWebsiteDataStore` UUID; `allowedHosts` includes `mail.google.com` and the relevant Google auth hosts; an integration test "open gmail" opens a Gmail pane; login persists across two cold launches.

- [ ] **T-P3-12: `SafetyLog` scaffold (`os.Logger`)**
  *Advances: US-SAFE-8*
  *Per brief: §11.7*
  *Depends on: T-P3-06*
  *Acceptance check:* `SafetyLog.urlDenied(host: "…")` writes to OSLog under subsystem = bundle ID, category = `safety`, with `.public` for the host enum and `.private` for the full URL; verifiable via `log show --predicate 'subsystem == "<bundle-id>" AND category == "safety"' --last 5m`. Other guardrails wire into this in Phase 5.

### Phase 4 — Native app control

- [ ] **T-P4-01 [USER]: Grant Accessibility permission to the dev build**
  *Advances: US-E-3, US-PERM-1*
  *Per brief: §9*
  *Depends on: T-P3-12*
  *Acceptance check:* `AXIsProcessTrusted()` returns true in a debug build of the app. Stop here and wait for the user to drag the app into System Settings → Privacy & Security → Accessibility.

- [ ] **T-P4-02: `AXElement`, `AXApplication`, `AXErrors` thin wrappers**
  *Advances: US-E-3*
  *Per brief: §5*
  *Depends on: T-P4-01*
  *Acceptance check:* Unit tests: `AXApplication(bundleId: "com.apple.finder")` returns a non-nil root; `findFirst(role: .button, title: "OK")` on a constructed mock element tree returns the expected element. AX traversal is synchronous IPC, so timeouts are tested at integration level.

- [ ] **T-P4-03: `AXObservation` → `AsyncStream` bridge**
  *Advances: US-E-3*
  *Per brief: §5*
  *Depends on: T-P4-02*
  *Acceptance check:* Test: subscribing to `kAXFocusedUIElementChangedNotification` on a known target app yields events when focus changes (manual verification on Finder).

- [ ] **T-P4-04: `AXLane` dispatcher**
  *Advances: US-E-3*
  *Per brief: §5*
  *Depends on: T-P4-02, T-P3-02*
  *Acceptance check:* Test: a `RawPlan` step `ax_action(bundle: "com.spotify.client", action: .press, selector: …)` is dispatched to the AX lane.

- [ ] **T-P4-05: `AXAdapter` protocol + `SpotifyAXAdapter`**
  *Advances: US-E-3*
  *Per brief: §5*
  *Depends on: T-P4-04*
  *Acceptance check:* Manual: command `play spotify` triggers Spotify play/pause via AX on a machine with Spotify open and logged in. AX traversal output is not logged at `.public` (verified in `SafetyLog` interpolation review).

- [ ] **T-P4-06: `MailAXAdapter` read-latest-subject hook**
  *Advances: US-E-3*
  *Per brief: §5*
  *Depends on: T-P4-05*
  *Acceptance check:* Manual: command `read my latest mail subject` returns the subject string from Mail.app's open window. A TODO comment is left where the subject string will route through `UntrustedContentFilter.wrap(…)` in Phase 5 (verified by a Phase 5 grep-for-TODO task).

- [ ] **T-P4-07: Mid-session AX revocation banner**
  *Advances: US-E-3, US-PERM-1*
  *Per brief: §9*
  *Depends on: T-P4-05*
  *Acceptance check:* Manual: revoke Accessibility in System Settings while the shell is open; the next AX call surfaces a non-blocking banner in the session log ("Accessibility was revoked — re-enable it in Settings"); the app does not crash.

- [ ] **T-P4-08: `AXDump` debug command + minimal `AdvancedTabView` invoker**
  *Advances: US-SET-7 (partial)*
  *Per brief: §5, §12.4 (per §6 decision #11)*
  *Depends on: T-P4-02*
  *Acceptance check:* From Advanced settings, entering bundle ID `com.apple.finder` and pressing "Dump AX tree" prints the tree into the session log; smoke test that the function returns non-empty output for Finder.

- [ ] **T-P4-09: `PermissionsManager` skeleton — Accessibility only**
  *Advances: US-PERM-1*
  *Per brief: §9*
  *Depends on: T-P4-01*
  *Acceptance check:* `PermissionsManager.accessibility` is `.granted` when `AXIsProcessTrusted()` is true, `.denied` otherwise. Automation and FDA states arrive in Phase 7.

### Phase 5 — Safety pipeline

- [ ] **T-P5-01: `RiskClass` enum and default action-to-risk mapping**
  *Advances: US-SAFE-4*
  *Per brief: §11.2*
  *Depends on: T-P4-09*
  *Acceptance check:* Table-driven test: `open_url(https://allowed)` → `.read`; `move_file(…trash…)` → `.reversible`; `delete_file(non-trash)` → `.destructive`; `place_order(...)` → `.spend`. Adapter override can raise the class but not lower it (compile-time check by `where Class >= Default`).

- [ ] **T-P5-02: `PlanRejection` enum + structured payload**
  *Advances: US-SAFE-2, US-SAFE-8*
  *Per brief: §11.3, §11.7*
  *Depends on: T-P5-01*
  *Acceptance check:* Each rejection case carries (a) a `reason: RejectionReason` enum (public-loggable), (b) a `planHash: String` (public-loggable), (c) a `humanMessage: String` (renderable inline).

- [ ] **T-P5-03: Real `PlanValidator` — URL validation**
  *Advances: US-SAFE-2, US-SAFE-3*
  *Per brief: §11.3, §11.4*
  *Depends on: T-P5-02, T-P3-06*
  *Acceptance check:* Tests: off-list host → reject; non-HTTPS → reject; userinfo → reject; IDN host `xn--…` normalized to ASCII then checked → expected result; unknown custom scheme → reject; rejection logged with reason + hash, not the plan body.

- [ ] **T-P5-04: Real `PlanValidator` — fail-closed unknown action types/fields**
  *Advances: US-SAFE-2*
  *Per brief: §11.3*
  *Depends on: T-P5-03*
  *Acceptance check:* Test: a `RawPlan` with an `action_type` not in the enum throws `PlanRejection.unknownActionType`; a plan with an unknown field on a known action throws `PlanRejection.unknownField`.

- [ ] **T-P5-05: Make `ValidatedPlan` constructible only by `PlanValidator`**
  *Advances: US-SAFE-2*
  *Per brief: §11.3 (type-level handoff)*
  *Depends on: T-P5-04*
  *Acceptance check:* The Phase-1 `phase1Allow(_:)` factory is removed; `ValidatedPlan.init` is file-private to `PlanValidator.swift`; a test in another file that tries to construct `ValidatedPlan(...)` fails to compile (verified by a `// EXPECTED-FAIL` marker file run separately). The `ExecutorRouter.dispatch(_:)` signature accepts only `ValidatedPlan`.

- [ ] **T-P5-06: `NSFWBlocklist` loader + bundled `nsfw-blocklist.txt`**
  *Advances: US-NSFW-1*
  *Per brief: §12.2*
  *Depends on: T-P3-12*
  *Acceptance check:* `NSFWBlocklist.contains("…")` returns expected results against a curated test list; loading takes < 100ms at app start on a representative dataset.

- [ ] **T-P5-07: `Scripts/refresh-nsfw-list.sh` maintainer script**
  *Advances: US-NSFW-1*
  *Per brief: §12.2*
  *Depends on: T-P5-06*
  *Acceptance check:* Script downloads the StevenBlack porn extension, parses host lines, writes `Singularity/Resources/nsfw-blocklist.txt`. Manual verification by running once.

- [ ] **T-P5-08: Fold NSFW check into `URLPolicy.evaluate`**
  *Advances: US-NSFW-1, US-SAFE-3*
  *Per brief: §12.2*
  *Depends on: T-P5-06*
  *Acceptance check:* Test: with NSFW toggle on, an NSFW-listed host is denied even if some hypothetical adapter were to list it; with NSFW toggle off, the same host is denied because the allowlist still doesn't include it. Toggle off never widens the allowlist (US-NSFW-1).

- [ ] **T-P5-09: `AuthorizationGate` (`LAContext.evaluatePolicy(.deviceOwnerAuthentication, …)`)**
  *Advances: US-SAFE-4*
  *Per brief: §11.2*
  *Depends on: T-P5-01*
  *Acceptance check:* Test (LAContext mocked): a Destructive step prompts Touch ID; on success returns `.authorized`; on cancel/fail returns `.denied`. Successful auth is cached 30s; after grace expiry, re-prompt. Cache cleared on shell dismiss. `NSFaceIDUsageDescription` exists in `Info.plist`.

- [ ] **T-P5-10: `ConfirmGate` + `ConfirmGateView`**
  *Advances: US-SAFE-5*
  *Per brief: §11.2*
  *Depends on: T-P5-09*
  *Acceptance check:* Test: Destructive/Spend plan step renders a modal-inline preview; explicit confirm required after Touch ID; Esc cancels cleanly; Amazon-purchase plan has two stops (add-to-cart + place-order) with Touch ID on the second.

- [ ] **T-P5-11: `EnvelopedContent` + `UntrustedContentFilter.wrap` and `scan`**
  *Advances: US-SAFE-6*
  *Per brief: §11.6*
  *Depends on: T-P5-04*
  *Acceptance check:* Tests: `wrap(content:source:)` produces `<UNTRUSTED-CONTENT source="…" id="…">…</UNTRUSTED-CONTENT>` with normalized unicode and escaped literal envelope tags; `scan(content:)` flags "ignore previous instructions", "you are now", action-type names; planner-context builder accepts only `EnvelopedContent` (verified by a compile-fail test on direct `String` append).

- [ ] **T-P5-12: `ContentRing` for cross-context contamination**
  *Advances: US-SAFE-6, US-SAFE-2*
  *Per brief: §11.6, §11.3*
  *Depends on: T-P5-11*
  *Acceptance check:* Test: a `RawPlan.run_shell` argument that contains a substring traceable to a recently wrapped untrusted content (ring of last 8 hashes) is rejected; the rejection reason is `.crossContextContamination`.

- [ ] **T-P5-13: Phase 4 untrusted-content wrap retrofit**
  *Advances: US-SAFE-6, US-E-3*
  *Per brief: §11.6*
  *Depends on: T-P5-11*
  *Acceptance check:* Grep for TODO comments left in Phase 4 AX adapters returns zero; all AX read outputs now flow through `UntrustedContentFilter.wrap`. Test: `MailAXAdapter.latestSubject()` returns `EnvelopedContent`.

- [ ] **T-P5-14: Instruction-detection risk escalation**
  *Advances: US-SAFE-6*
  *Per brief: §11.6 (per §6 decision #4)*
  *Depends on: T-P5-11, T-P5-09*
  *Acceptance check:* Test: a wrapped content with "ignore previous instructions" raises a warning into the session log AND the resulting plan's risk class is downgraded one level harsher (a Reversible plan becomes Destructive and now requires Touch ID).

- [ ] **T-P5-15: `PanicController` (`abort` + double-Esc, `Task.cancel()` propagation)**
  *Advances: US-SAFE-7*
  *Per brief: §11.1*
  *Depends on: T-P5-04*
  *Acceptance check:* Test: typing `abort` while an executor task is mid-flight calls `Task.cancel()` on the root task; double-Esc within 500ms has the same effect; `SafetyLog.panicCancelled()` is emitted; in-flight `ConfirmGate` is dismissed.

- [ ] **T-P5-16: `SafetyLog` full API surface**
  *Advances: US-SAFE-8*
  *Per brief: §11.7*
  *Depends on: T-P5-04, T-P5-09, T-P5-11, T-P5-15*
  *Acceptance check:* Every guardrail (input blocked, plan rejected, URL denied, auth failed, untrusted-heuristic fired, panic cancelled) routes through `SafetyLog`. Privacy markers verified: enums/hashes/hosts are `.public`; URLs/contents/user text are `.private`. A code-review checklist task.

- [ ] **T-P5-17: `Routine` model + `RoutineStore` actor**
  *Advances: US-RT-1 (foundation), US-RT-4, US-RT-5 (foundation)*
  *Per brief: §11 (per §6 decision #13)*
  *Depends on: T-P5-04*
  *Acceptance check:* Tests: load from non-existent file returns empty; upsert writes atomically (temp + `rename(2)`); concurrent upserts serialize correctly through the actor; delete removes the entry and persists. No UI here — storage layer only (per spec §10 Phase 5 note).

- [ ] **T-P5-18: Wire real `PlanValidator` into `CommandPipeline`**
  *Advances: US-SAFE-2*
  *Per brief: §11.3*
  *Depends on: T-P5-05, T-P5-10, T-P5-15*
  *Acceptance check:* The Phase-1 stub is removed from `CommandPipeline.swift`; integration test: hero command still works (regression); a malformed `RawPlan` (injected via a test seam) is rejected before reaching the router.

- [ ] **T-P5-19: `SettingsStore` adds Safety settings + `SafetyTabView`**
  *Advances: US-SET-3*
  *Per brief: §12.4*
  *Depends on: T-P5-08, T-P5-09, T-P5-15*
  *Acceptance check:* Tab exposes NSFW toggle (default on, verbatim disclaimer), Touch ID grace (default 30, range 0–300), panic phrase (default `abort`), read-only allowlist viewer. Changes take effect immediately.

- [ ] **T-P5-20: `AmazonAdapter` two-stop checkout flow**
  *Advances: US-SAFE-5, US-E-2*
  *Per brief: §11.2*
  *Depends on: T-P5-10*
  *Acceptance check:* Adapter declares two RiskClass.spend steps with explicit `ConfirmGate` previews; integration test (with a mock checkout fixture) verifies both stops fire and Touch ID is required on the second.

- [ ] **T-P5-21: Phase 5 hardening test pass**
  *Advances: US-SAFE-1..8, US-NSFW-1*
  *Per brief: §11*
  *Depends on: T-P5-20*
  *Acceptance check:* Comprehensive integration test suite passes: credential paste rejection, allowlist denial, Touch ID re-prompt after grace expiry, indirect-injection risk escalation, cross-context contamination rejection, panic-cancel mid-flight. See §6 Phase 5 test plan.

### Phase 6 — System and file lanes

- [ ] **T-P6-01: `Info.plist` adds `NSAppleEventsUsageDescription`; entitlements add `com.apple.security.automation.apple-events`**
  *Advances: US-E-4*
  *Per brief: §6*
  *Depends on: T-P5-21*
  *Acceptance check:* App builds with hardened runtime + the entitlement; manual: first AppleScript dispatch to a new target app prompts the per-app Automation consent dialog.

- [ ] **T-P6-02: `CompiledScriptCache` + `AppleScriptLane`**
  *Advances: US-E-4*
  *Per brief: §6*
  *Depends on: T-P6-01*
  *Acceptance check:* Test: a script `tell application "Finder" to get name of front window` compiles once and is cached; second dispatch reuses the compiled `NSAppleScript`.

- [ ] **T-P6-03: `MailAppleScriptAdapter` (read, draft, send)**
  *Advances: US-E-4*
  *Per brief: §6*
  *Depends on: T-P6-02, T-P5-10*
  *Acceptance check:* Manual: reading latest mail subject returns the string; drafting is reversible (no Touch ID); sending requires Touch ID + confirm. Mail body strings flow through `UntrustedContentFilter.wrap`.

- [ ] **T-P6-04: `CalendarAppleScriptAdapter`, `MusicAppleScriptAdapter`, `FinderAppleScriptAdapter`, `RemindersAppleScriptAdapter`, `NotesAppleScriptAdapter`, `SafariAppleScriptAdapter`**
  *Advances: US-E-4*
  *Per brief: §6*
  *Depends on: T-P6-02*
  *Acceptance check:* Each adapter has at least one read and one write op; write ops route through `AuthorizationGate` per their RiskClass. Manual smoke for each.

- [ ] **T-P6-05: Errors and Messages/Photos known-constraint messages**
  *Advances: US-E-4*
  *Per brief: §6*
  *Depends on: T-P6-04*
  *Acceptance check:* `errAEEventNotPermitted (-1743)` surfaces a "grant in Settings" hint; Messages-write-only and Photos-limited surfaces explicit fallback messages in the session log rather than silent partial results.

- [ ] **T-P6-06: `FileOperations` (`FileManager` move/copy/list/trash)**
  *Advances: US-E-5*
  *Per brief: §7*
  *Depends on: T-P5-21*
  *Acceptance check:* Tests: move, copy, list work; `delete` uses `FileManager.trashItem(at:resultingItemURL:)` (not `removeItem`); a test asserting `removeItem` is not called for any user-initiated delete path.

- [ ] **T-P6-07: `StagingStore` (copy-to-staging, retain N=10)**
  *Advances: US-E-5*
  *Per brief: §7*
  *Depends on: T-P6-06*
  *Acceptance check:* Test: an in-place edit copies the original to `~/Library/Application Support/Singularity/staging/<timestamp>/…`; after 11 edits, the oldest staged copy is removed; retention configurable via SettingsStore default 10.

- [ ] **T-P6-08: `ShellValidator` static rules**
  *Advances: US-E-5, US-SAFE-2*
  *Per brief: §11.3*
  *Depends on: T-P5-04*
  *Acceptance check:* Table-driven tests: `curl … | sh` → reject; `wget … | bash` → reject; `echo "$x" | base64 -d | bash` → reject; `eval "$cmd"` → reject; `cd /tmp && ../../etc/passwd` → reject; access to `~/Library/Mail` without declared intent → reject.

- [ ] **T-P6-09: `FilePathValidator` (symlink resolution + scope re-check)**
  *Advances: US-SAFE-2, US-E-5*
  *Per brief: §11.3*
  *Depends on: T-P5-04*
  *Acceptance check:* Test: a path with a symlink that escapes the declared scope is rejected; in-scope paths with no symlink escape pass; `..` traversal that resolves outside scope is rejected.

- [ ] **T-P6-10: `PlanValidator` integrates `ShellValidator` and `FilePathValidator`**
  *Advances: US-SAFE-2*
  *Per brief: §11.3*
  *Depends on: T-P6-08, T-P6-09*
  *Acceptance check:* Validator rejects shell-rule violations and file-path-rule violations with structured `PlanRejection`s.

- [ ] **T-P6-11: Action-graph taint check**
  *Advances: US-SAFE-2*
  *Per brief: §11.3*
  *Depends on: T-P6-10*
  *Acceptance check:* Test: a 2-step plan where step 2's shell argument is derived from step 1's read content gets tagged as tainted; the validator either rejects or escalates risk to Destructive (configurable per spec §6 #4 default = escalate).

- [ ] **T-P6-12: `SandboxRunner` + `SandboxProfile.sb`**
  *Advances: US-E-5*
  *Per brief: §8*
  *Depends on: T-P6-08*
  *Acceptance check:* Tests: running `echo hello` returns "hello"; an attempted `curl example.com` fails with a sandbox-denied error (network denied); writing outside the declared working directory fails; spawning `ssh` fails (not on the utility whitelist).

- [ ] **T-P6-13: `FilesLane` dispatcher**
  *Advances: US-E-5*
  *Per brief: §7, §8*
  *Depends on: T-P6-06, T-P6-12*
  *Acceptance check:* Test: a `RawPlan.file_op(move, src, dst)` dispatches to `FileOperations.move`; a `RawPlan.run_shell(cmd)` dispatches to `SandboxRunner.run(cmd, profile:)`; both route through `AuthorizationGate` per RiskClass.

- [ ] **T-P6-14 [USER]: Grant Full Disk Access to the dev build**
  *Advances: US-E-5, US-PERM-1*
  *Per brief: §9*
  *Depends on: T-P6-13*
  *Acceptance check:* Reading `~/Library/Mail` succeeds; if denied, the lane surfaces the standard permission-needed banner.

### Phase 7 — Daily-driver polish

- [ ] **T-P7-01 [USER]: Register App ID + enable Sign in with Apple capability**
  *Advances: US-ID-1*
  *Per brief: §12.1*
  *Depends on: T-P6-14*
  *Acceptance check:* The user has provisioned an App ID with "Sign in with Apple" enabled in Apple Developer; the team ID and bundle ID are recorded for the entitlements. Stop here.

- [ ] **T-P7-02: `IdentityRecord` + `IdentityStore` Keychain wrapper**
  *Advances: US-ID-1, US-ID-3*
  *Per brief: §12.1*
  *Depends on: T-P7-01*
  *Acceptance check:* Tests: write/read of `IdentityRecord` to Keychain at `kSecAttrService = "<bundle-id>.identity"`, `kSecAttrAccount = "appleID"`, `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; delete clears.

- [ ] **T-P7-03: `AppleIDSignIn` (`SignInWithAppleButton`)**
  *Advances: US-ID-1*
  *Per brief: §12.1*
  *Depends on: T-P7-02*
  *Acceptance check:* Manual: first run shows the Sign in with Apple button + a "Skip for now" affordance; on success, `IdentityStore` contains `{user, fullName?, email?}`; `identityToken` and `authorizationCode` are not persisted (asserted via Keychain dump).

- [ ] **T-P7-04: `CredentialStateChecker` (launch-time check)**
  *Advances: US-ID-2*
  *Per brief: §12.1*
  *Depends on: T-P7-03*
  *Acceptance check:* Test: with a stored identity, `getCredentialState(forUserID:)` is called on launch; `.revoked` / `.notFound` / `.transferred` clears Keychain and re-presents first-run on next shell open; `.authorized` leaves state intact.

- [ ] **T-P7-05: Sign-out from Account tab**
  *Advances: US-ID-3*
  *Per brief: §12.3*
  *Depends on: T-P7-02*
  *Acceptance check:* Sign Out button opens a confirm sheet; on confirm, Keychain entry is deleted and in-memory state cleared; next shell open re-presents first-run.

- [ ] **T-P7-06: `PermissionsManager` adds Automation cache + FDA probe + 2s polling-when-foregrounded**
  *Advances: US-SET-5, US-PERM-1*
  *Per brief: §9, §12.5*
  *Depends on: T-P4-09, T-P6-14*
  *Acceptance check:* Tests: Automation cache populates from AppleScript adapter call results (`-1743` → denied, success → granted); FDA probe reads a TCC-protected path and inspects `EPERM`; polling fires every 2s only while the Permissions tab is foreground.

- [ ] **T-P7-07: `SystemSettingsLinks` + open-with-fallback helper**
  *Advances: US-SET-5, US-PERM-1*
  *Per brief: §12.5*
  *Depends on: T-P7-06*
  *Acceptance check:* The three deep links open the correct System Settings panes on macOS 14 and 15; if a specific link fails, the fallback opens the parent Privacy & Security pane.

- [ ] **T-P7-08: `FirstRunFlow` + `FirstRunView`**
  *Advances: US-PERM-1, US-ID-1*
  *Per brief: §9, §12.1*
  *Depends on: T-P7-06, T-P7-03*
  *Acceptance check:* On a freshly installed app, first launch shows the checklist (Accessibility, Automation, FDA) + Sign in with Apple step + "Skip for now"; shell is reachable even with not-yet-granted permissions; lanes that need the missing permission surface a clean banner.

- [ ] **T-P7-09: Mid-session permission revocation banner (all three)**
  *Advances: US-PERM-1, US-E-3, US-E-4, US-E-5*
  *Per brief: §9*
  *Depends on: T-P7-06*
  *Acceptance check:* Manual: revoking any of the three TCC permissions mid-session surfaces a non-blocking banner; lane calls fail cleanly, no crash, no modal.

- [ ] **T-P7-10: `SettingsScene` with 7-tab `TabView`**
  *Advances: US-SET-1..7*
  *Per brief: §12.3, §12.4*
  *Depends on: T-P7-08*
  *Acceptance check:* Opening Settings (via `SettingsLink` or `openSettings`) shows seven tabs in order: General, Planner, Safety, Routines, Permissions, Account, Advanced.

- [ ] **T-P7-11: `GeneralTabView` (hotkey, launch-at-login, appearance)**
  *Advances: US-SET-1*
  *Per brief: §12.4*
  *Depends on: T-P7-10*
  *Acceptance check:* Rebinding the hotkey via the recorder field replaces the old combo without restart; `SMAppService` toggle persists across restarts; appearance picker writes `NSApp.appearance`.

- [ ] **T-P7-12: `PlannerTabView` (model picker from `/api/tags`, URL, timeout, Apply)**
  *Advances: US-SET-2, US-P-3*
  *Per brief: §12.4*
  *Depends on: T-P7-10, T-P2-10*
  *Acceptance check:* Model picker populates from `GET /api/tags` against the configured base URL; on tags failure, free-text entry is allowed as fallback; "Apply" button confirms; mid-plan changes don't take effect until next command.

- [ ] **T-P7-13: `RoutineParser` + reserved-word check**
  *Advances: US-RT-1, US-RT-6*
  *Per brief: §11 (per §6 decisions #12 / #18)*
  *Depends on: T-P5-17*
  *Acceptance check:* Tests: `routine dev = open vscode; cd ~/code` parses to `("dev", ["open vscode", "cd ~/code"])`; reserved words (`routine`, `routines`, `abort`, `run`, `delete`, `cancel`, `help`, `settings`, `quit`, `exit`) → reject; whitespace in NAME → reject; `=` missing → reject; empty step list → reject; unbalanced quote → reject.

- [ ] **T-P7-14: `RoutineResolver` (bare-name + `run NAME`, no mid-sentence)**
  *Advances: US-RT-2, US-RT-6*
  *Per brief: §11 (per §6 decisions #15 / #17)*
  *Depends on: T-P7-13*
  *Acceptance check:* Tests: bare `dev` invokes routine `dev`; `run dev` invokes routine `dev`; `tell me about dev tooling` does NOT invoke routine `dev`; `dev tools` (whitespace) does NOT invoke; case-insensitive; unknown bare name falls through to the planner; unknown `run NAME` surfaces "No routine named 'NAME'.".

- [ ] **T-P7-15: `RoutineCommandHandler` for inline create / list / delete**
  *Advances: US-RT-1, US-RT-3, US-RT-4 (inline form), US-RT-5*
  *Per brief: §11 (per §6 decisions #12, #15, #17)*
  *Depends on: T-P7-13*
  *Acceptance check:* Tests: `routine NAME = …` persists; overwrite requires trailing `overwrite` token; `routines` lists all; `routine NAME` (no `=`) shows the full step list; `routine delete NAME` requires literal `confirm` on next input; deleting unknown name surfaces "No routine named 'NAME'." and is a no-op.

- [ ] **T-P7-16: Wire `RoutineResolver` and `RoutineCommandHandler` into `CommandPipeline`**
  *Advances: US-RT-1..6, US-P-1 (resolver runs before planner)*
  *Per brief: §11 (per §6 decisions #12–#17)*
  *Depends on: T-P7-14, T-P7-15*
  *Acceptance check:* Order verified by test: input → InputValidator → RoutineCommandHandler (if `routine`/`routines`) → RoutineResolver (expand bare-name or `run NAME`) → for each expanded step: re-enter the pipeline as if typed → Planner → PlanValidator → ExecutorRouter. `abort` mid-routine cancels the in-flight step and skips remaining steps; the log notes counts.

- [ ] **T-P7-17: `RoutinesTabView`**
  *Advances: US-SET-4, US-RT-3, US-RT-4 (Settings form), US-RT-5 (Settings form)*
  *Per brief: §12 (per §6 decision #14)*
  *Depends on: T-P7-10, T-P7-16*
  *Acceptance check:* Tab lists routines (name, step count, single-line preview); selecting opens detail with free-form text editor; Edit mode + Save validates via the same parser; Delete prompts confirm; reveal-in-Finder footer opens `routines.json`; no "New routine" button.

- [ ] **T-P7-18: `PermissionsTabView`**
  *Advances: US-SET-5*
  *Per brief: §12.5*
  *Depends on: T-P7-10, T-P7-06, T-P7-07*
  *Acceptance check:* One section per permission (Accessibility, Automation per-target sub-list, FDA); live tinted status; explanation paragraph; "Open System Settings" button; footer link re-runs first-run onboarding.

- [ ] **T-P7-19: `AccountTabView`**
  *Advances: US-SET-6, US-ACC-1*
  *Per brief: §12.3*
  *Depends on: T-P7-10, T-P7-05*
  *Acceptance check:* Three sections (Identity, About, Sign-out footer); avatar = initials in colored circle (or generic person SF Symbol); `(relayed)` label when email ends in `privaterelay.appleid.com`; About shows version + build + privacy policy button (opens in default browser, not in a pane); no upsells. Signed-out state shows "Not signed in" + a button that re-runs first-run identity.

- [ ] **T-P7-20: `AdvancedTabView` log viewer (`OSLogStore`, last hour, safety category)**
  *Advances: US-SET-7, US-SAFE-8*
  *Per brief: §11.7, §12.4*
  *Depends on: T-P7-10*
  *Acceptance check:* Tab renders the last hour of `subsystem == <bundle-id> AND category == "safety"` entries from `OSLogStore`; auto-refreshes on tab open.

- [ ] **T-P7-21: `/safety log` inline invoker**
  *Advances: US-SET-7, US-SAFE-8*
  *Per brief: §11.7*
  *Depends on: T-P7-20*
  *Acceptance check:* Typing `/safety log` in the shell prints the same last-hour log into the session log.

- [ ] **T-P7-22: `FactoryReset` + Advanced tab button**
  *Advances: US-SET-7*
  *Per brief: §12.4*
  *Depends on: T-P7-20, T-P7-02, T-P5-17*
  *Acceptance check:* Factory Reset opens a confirmation sheet that explicitly lists what will be deleted (Keychain identity entry, all `UserDefaults`, per-adapter `WKWebsiteDataStore` directories under `~/Library/WebKit/WebsiteDataStore`, `~/Library/Application Support/Singularity/routines.json`); on confirm, all four are removed; next launch behaves like fresh install.

- [ ] **T-P7-23: Latency tuning pass**
  *Advances: (cross-cut performance)*
  *Per brief: §1, §2, §4*
  *Depends on: T-P7-22*
  *Acceptance check:* Hero command median latency from Return to first frame of video remains under 5s on a representative M-series 16GB; Settings open latency under 200ms; hotkey-to-focus under 150ms (US-S-1 acceptance regression).

- [ ] **T-P7-24: Final end-to-end acceptance walk**
  *Advances: all 39 user stories*
  *Per brief: §10 (overall)*
  *Depends on: T-P7-23*
  *Acceptance check:* Walk the full spec §4 user-story acceptance checklists top to bottom; every box flips. Document any deviation in §8 of this plan and stop for human review before shipping.

---

## 5. Crosscut: where the safety pipeline lives

The safety pipeline lands in Phase 5 by mandate (CLAUDE.md "build before enabling any shell/file execution", spec §10). Earlier phases create deliberate stubs and TODO markers so Phase 5 has clean wiring points; Phase 6 is *blocked* on Phase 5 being real before it ships any shell or file execution.

**Stubs that Phase 5 fills.**

- `T-P1-02` creates a Phase-1 `ValidatedPlan` with a factory `phase1Allow(_:)` clearly marked `TODO: remove in Phase 5`. `T-P5-05` removes that factory and makes the init file-private to `PlanValidator`. After Phase 5 the type system enforces that **the only way to obtain a `ValidatedPlan` is through `PlanValidator.validate(_:) -> Result<ValidatedPlan, PlanRejection>`** — this is the single point where the spec's "you cannot reach the executor without a `ValidatedPlan`" rule (spec §6 #3, brief §11.3) is enforced at compile time.
- `T-P1-09` wires `ExecutorRouter` to accept a `ValidatedPlan`. Phase 1 builds them via the stub; Phase 5 builds them only via `PlanValidator`.
- `T-P3-06` creates `URLPolicy.evaluate` with allowlist + HTTPS + userinfo checks. `T-P5-08` adds the NSFW layer ahead of the allowlist check, inside the same helper. There is exactly one URL decision point.
- `T-P3-12` creates the `SafetyLog` API skeleton; `T-P5-16` fills out every guardrail call-site to route through it with the right privacy markers.
- `T-P4-06` leaves a TODO marker on `MailAXAdapter` for routing read output through `UntrustedContentFilter.wrap(…)`. `T-P5-13` retrofits all Phase 4 AX adapters; the grep-for-TODO step is the acceptance check.
- `T-P1-10` wires `CommandPipeline` with the stub validator inline; `T-P5-18` swaps in the real `PlanValidator`, `AuthorizationGate`, `ConfirmGate`, and `PanicController`.
- `T-P5-17` (the storage layer for routines) lands in Phase 5 even though the user-facing routines surfaces are Phase 7 (per spec §10 explicit Phase 5 note). This lets the Phase 7 inline-command handler and Settings tab build directly on a stable persistence API rather than refactoring a Phase 7 store mid-build.

**Phase 6 tasks blocked until Phase 5 ships.**

- `T-P6-02` AppleScript lane → blocked on `T-P5-09` (AuthorizationGate) and `T-P5-10` (ConfirmGate) being real, because write ops are not allowed to ship without those gates.
- `T-P6-12` SandboxRunner → blocked on `T-P5-21` (Phase 5 hardening pass) and on `T-P6-08` ShellValidator (which itself depends on `T-P5-04` real PlanValidator). No `sandbox-exec` shell lane until the real PlanValidator is enforcing the static rules.
- `T-P6-13` FilesLane → blocked on `T-P5-21` and `T-P6-10` (PlanValidator integrating shell + file-path checks).
- `T-P6-11` action-graph taint check → blocked on `T-P5-11` (UntrustedContentFilter / EnvelopedContent) and `T-P5-12` (ContentRing) because the taint check needs the content-hash ring to compare against.

**The single point that enforces "no executor without a `ValidatedPlan`":** `Singularity/Safety/ValidatedPlan.swift` after `T-P5-05`. Its initializer is file-private to `PlanValidator.swift`, and `ExecutorRouter.dispatch(_:)` accepts only `ValidatedPlan`. The implementer must not add any overload that takes `RawPlan` or any other plan-shaped type, ever.

---

## 6. Test strategy

Tests use Swift Testing (`@Test`) by default; XCTest only where Swift Testing does not yet cover the surface (XCUITest for UI flows). All tests live under `SingularityTests/` mirroring the source tree. Safety pipeline tests are non-negotiable per CLAUDE.md.

### Phase 0
- *Unit:* `KeyCombo` JSON round-trip; `ShellPanel` style mask / level / collection behavior assertions; `SessionLog.clear()` empties; `Compositor` add/remove counts; `CommandInput` 4KB cap.
- *Integration:* Launch, hotkey, type, log, dismiss (XCUITest scripted).
- *Manual:* Stage Manager on/off; multi-display cursor-screen selection; menu bar + Dock hidden while visible; hotkey from Safari foreground actually fires (there is no headless way to test a Carbon-registered global hotkey).

### Phase 1
- *Unit:* `StringMatcherPlanner` returns the expected `RawPlan` for the hero phrase; `YouTubeAdapter.allowedHosts` shape; `waitForSelector` resolves vs. times out on a local HTML fixture.
- *Integration:* Hero command end-to-end (XCUITest + a real `WKWebView` in a hidden window).
- *Manual:* Cold-launch-to-video under 5s on a representative Apple Silicon; login persists across two cold launches; dismiss stops playback.

### Phase 2
- *Unit:* `OllamaClient` mocked → varied error paths; `OllamaPlanner` validate→repair→fail-loud (mocked client); `SecretPatterns` table-driven; `RateLimiter` time-windowed; `InputValidator` normalizes / scans / caps.
- *Integration:* With live local Ollama, varied-phrasing equivalence on the hero phrase; injection-attempt-shaped input is dropped before reaching Ollama.
- *Manual:* `ollama serve` killed mid-command → `PlannerError.unreachable` surfaces a clean line.

### Phase 3
- *Unit:* `URLPolicy.evaluate` table-driven (HTTPS only, off-list, userinfo, IDN); `AllowedDomains` union; `AllowlistNavigationDelegate` policy decisions on a fake `WKNavigationAction`; download default-deny.
- *Integration:* Multiple web adapters dispatched through one router; YouTube and Gmail panes coexist with separate `WKWebsiteDataStore`s (cookies do not cross).
- *Manual:* `window.open` from a fixture HTML correctly routes through the nav delegate.

### Phase 4
- *Unit:* `AXElement` find-by-role-and-title on a mock element tree; `AXErrors` mapping from `AXError` constants.
- *Integration:* `axdump` against Finder returns non-empty.
- *Manual (required):* Spotify play/pause via `SpotifyAXAdapter`; revoke Accessibility mid-session and verify the banner appears, no crash.

### Phase 5 (non-negotiable per CLAUDE.md)
Required test cases — call out by name:
- **Credential paste rejection.** AWS, GitHub PAT, OpenAI key, Slack, Stripe, Google, Luhn PAN, SSN — all eight categories drop the input, do not log it, and surface the correct inline message naming the category.
- **Allowlist denial.** A `RawPlan` whose `open_url` host is not in `AllowedDomains` is rejected with `PlanRejection.urlDenied`; the host is logged `.public`, the URL `.private`.
- **HTTPS-only and userinfo rejection.** `http://…` denied; `https://user:pass@…` denied; `file://` / `data:` / `javascript:` denied.
- **IDN homograph defense.** A Punycode host normalized to ASCII matches the allowlist; an off-list IDN host is denied after normalization.
- **Touch ID re-prompt after grace expiry.** Two Destructive commands within 30s → one prompt; after 30s → second prompt. After shell dismiss → cache cleared, next command re-prompts.
- **Touch ID cancel.** User cancels Touch ID → action does not run; clean error in log; no crash.
- **ConfirmGate cancel.** Esc on the preview cancels cleanly.
- **Amazon two-stop.** Both hard stops fire; Touch ID required on the second.
- **Indirect-injection escalation.** A wrapped content containing "ignore previous instructions" emits a warning and downgrades the next plan's risk class one level harsher.
- **Cross-context contamination.** A `run_shell` argument containing a substring traceable to a recently wrapped untrusted content is hard-rejected.
- **Panic phrase.** Typing `abort` mid-flight cancels via `Task.cancel()`; double-Esc within 500ms same effect; `SafetyLog.panicCancelled()` is emitted; multi-step routine notes how many ran and how many were skipped.
- **NSFW toggle does not widen the allowlist.** With toggle off, an NSFW-listed host that no adapter declares is still denied because the allowlist still denies it.
- **`ValidatedPlan` compile-time barrier.** A compile-fail test (separate test file with `// EXPECTED-FAIL` marker) verifies that constructing `ValidatedPlan` outside `PlanValidator.swift` fails to compile.
- **`SafetyLog` privacy discipline.** Code-review checklist task: every `SafetyLog.*` call-site verified by hand that user-content fields are `.private` and only hashes/enums/hosts are `.public`.

### Phase 6
- *Unit:* `ShellValidator` table-driven (`curl|sh`, base64-to-bash, `..` escape, TCC paths); `FilePathValidator` symlink-escape; `SandboxRunner` denies network / out-of-scope write / non-whitelisted spawn; `CompiledScriptCache` reuse.
- *Integration:* MailAppleScriptAdapter read returns subject string, wrapped via `UntrustedContentFilter`; trash-instead-of-delete is enforced; staging retention N=10.
- *Manual:* First AppleScript to a new target app triggers the per-app consent dialog.

### Phase 7
- *Unit:* `RoutineParser` table-driven (valid forms, reserved words, malformed); `RoutineResolver` bare-name vs mid-sentence vs `run NAME`; `IdentityStore` Keychain round-trip; `PermissionsManager` state derivation; `CredentialStateChecker` clears Keychain on `.revoked`.
- *Integration:* First-run flow on a fresh install; sign in with Apple → Settings → Account shows identity; sign out → Account shows "Not signed in"; Factory Reset clears all four targets and next launch behaves like fresh install.
- *Manual:* Hotkey rebind without restart; launch-at-login persists across reboot; deep links to System Settings open the right pane on macOS 14 and 15.

---

## 7. Type contracts (interface inventory)

Implementer should not invent new protocol shapes for these areas without raising back.

```swift
// Planner
protocol PlannerProtocol {
    func plan(_ raw: String) async throws -> RawPlan
}
struct RawPlan { let steps: [PlanStep] }                    // unvalidated
struct PlanStep { let action: Action; let metadata: [String: AnyCodable] }
enum Action {                                                // shared Planner ↔ Executor
    case openURL(URL)
    case runScript(adapter: String, hook: String, args: [String: AnyCodable])
    case axAction(bundleID: String, action: AXActionKind, target: AXSelector)
    case appleScript(adapter: String, hook: String, args: [String: AnyCodable])
    case fileOp(FileOp)
    case runShell(command: String, scope: URL)
}

// Safety
struct ValidatedPlan { fileprivate init(_ raw: RawPlan) { ... } let steps: [PlanStep] }
enum SafetyVerdict { case allow, deny(PlanRejection) }
enum RiskClass: Comparable { case read, reversible, destructive, spend }
struct EnvelopedContent { fileprivate init(...) let envelope: String }
enum PlanRejection: Error {
    case urlDenied(host: String, planHash: String)
    case shellRuleViolation(rule: ShellRule, planHash: String)
    case filePathEscape(planHash: String)
    case crossContextContamination(planHash: String)
    case unknownActionType(planHash: String)
    case unknownField(planHash: String)
    case internalError(planHash: String)
}
enum URLPolicy {
    static func evaluate(_ url: URL) -> SafetyVerdict          // NSFW + allowlist + HTTPS + userinfo
}
protocol AuthorizationGate {
    func authorize(action: String, risk: RiskClass) async -> AuthorizationResult
}
protocol ConfirmGate {
    func confirm(preview: ConfirmPreview) async -> Bool
}
protocol SandboxRunner {
    func run(_ command: String, profile: SandboxProfile, scope: URL) async throws -> ShellResult
}

// Executor
protocol ExecutorLane {
    func canHandle(_ step: PlanStep) -> Bool
    func execute(_ step: PlanStep) async throws -> LaneResult
}
struct LaneResult { let summary: String; let pane: Pane? }

// Web
protocol WebAdapter {
    var dataStoreIdentifier: UUID { get }
    var allowedHosts: Set<AllowedHost> { get }
    var contentWorldName: String { get }
    var allowsDownloads: Bool { get }
    func resolveHook(_ name: String) -> WebAdapterHook?
}

// AX
protocol AXAdapter {
    var bundleID: String { get }
    func resolveAction(_ name: String) -> AXAdapterAction?
}

// AppleScript
protocol AppleScriptAdapter {
    var bundleID: String { get }
    var scripts: [String: CompiledAppleScript] { get }
}

// Identity
protocol IdentityStore {
    func read() throws -> IdentityRecord?
    func write(_ record: IdentityRecord) throws
    func clear() throws
}
struct IdentityRecord: Codable { let user: String; let displayName: String?; let email: String? }

// Permissions
protocol PermissionsManaging {
    var accessibility: PermissionState { get }
    var fullDiskAccess: PermissionState { get }
    var automation: [String: PermissionState] { get }
    func startPolling() ; func stopPolling()
}
enum PermissionState { case granted, denied, unknown }

// Routines
protocol RoutineStore: Actor {
    func all() async -> [Routine]
    func upsert(_ routine: Routine) async throws
    func delete(name: String) async throws
}
struct Routine: Codable { let name: String; let steps: [String]; let createdAt: Date; let updatedAt: Date }
struct RoutineResolver {
    enum Resolution { case expanded([String]), passthrough(String), notFound(name: String) }
    func resolve(_ rawInput: String) async -> Resolution
}

// Settings
@Observable final class SettingsStore { ... }                  // single source of truth

// Logging
enum SafetyLog {
    static func inputBlocked(reason: InputBlockReason)
    static func planRejected(_ rejection: PlanRejection)
    static func urlDenied(_ url: URL?)
    static func authFailed(action: String)
    static func untrustedHeuristicFired(source: String, pattern: String)
    static func panicCancelled()
}
```

---

## 8. Open architectural decisions

*(Empty. The spec §6 resolved 18 design decisions and §11 is empty by design. Every architectural choice required to execute this plan can be made from spec + brief defaults. If the implementer surfaces a new architectural question that the spec and brief do not answer, they must stop and raise it here for the architect before proceeding.)*

---

## 9. Phase exit criteria

Tighter than per-task acceptance: this is the "we could safely start the next phase" or "we could ship if we stopped here" bar.

### Phase 0
- App launches with no Dock icon; hotkey summons a fullscreen panel on the cursor's screen; menu bar and Dock hidden while visible; typing in the input works; session log appends; placeholder panes can be added and removed; dismiss restores the previous app's focus; reopening yields an empty log and empty compositor.
- `xcodebuild test`, `swiftlint`, `swift-format` all clean.

### Phase 1
- Hero command end-to-end works on a representative Apple Silicon Mac in under 5 seconds cold-launch; YouTube login persists across cold launches; allowlist denies non-YouTube/googlevideo navigation; dismiss stops playback.
- `ValidatedPlan` stub in place with explicit `TODO` for Phase 5 removal.
- All Phase 0 exit criteria still hold (no regression).

### Phase 2
- Three varied phrasings of the hero intent resolve to functionally equivalent plans through real local Ollama.
- Malformed Ollama output triggers exactly one repair attempt; second failure yields a clean "I didn't understand — try rephrasing".
- All eight credential categories are dropped before reaching Ollama with no raw string in any log.
- Hero command still works end-to-end (regression).
- Rate limits enforce 20/min and 200/hr.

### Phase 3
- At least two web adapters (YouTube, Gmail) coexist with independent persistent data stores.
- URL-scheme lane dispatches `spotify:` correctly.
- `URLPolicy.evaluate` is the only URL decision point used by lanes 1 and 2.
- `SafetyLog` writes correctly into OSLog with proper privacy markers.

### Phase 4
- Spotify native play/pause via AX works on a logged-in Spotify; Mail latest-subject read returns the string.
- Accessibility revocation mid-session produces a non-blocking banner, no crash.
- `axdump` produces non-empty AX-tree output for Finder from the Advanced tab.
- AX read outputs are not logged at `.public` (verified by code review).

### Phase 5
- All non-negotiable Phase 5 tests in §6 pass.
- The Phase-1 `ValidatedPlan` stub is removed; the type-system gate is enforced.
- `UntrustedContentFilter` is the only path from a read primitive to the planner context buffer.
- `AuthorizationGate` and `ConfirmGate` are wired into every mutating dispatch.
- NSFW toggle works and does not widen the allowlist.
- `RoutineStore` storage layer is real and tested (no UI yet).
- Hero command still works (regression).

### Phase 6
- AppleScript lane controls Mail / Calendar / Music / Finder / Reminders / Notes / Safari with at least one read and one write op each; write ops gated by `AuthorizationGate` per RiskClass.
- File lane uses `FileManager.trashItem` for deletes; staging retains N=10.
- `SandboxRunner` denies network, denies out-of-scope writes, denies non-whitelisted spawns.
- `PlanValidator` integrates `ShellValidator`, `FilePathValidator`, and action-graph taint check.
- All Phase 5 tests still pass (regression).

### Phase 7
- First-run flow shows three permissions + Sign in with Apple step (skip-able); shell is reachable even with not-yet-granted permissions.
- All seven Settings tabs are present and functional (General, Planner, Safety, Routines, Permissions, Account, Advanced).
- Routines can be created, listed, edited, deleted (inline and Settings), invoked (bare-name and `run NAME`), and never expand mid-sentence.
- Account tab shows identity correctly; sign-out works and re-presents first-run on next launch.
- Permissions tab live-polls every 2s while foregrounded; deep links open the right System Settings panes; fall back to parent Privacy & Security pane on individual-link failure.
- Factory Reset clears all four targets and next launch behaves like fresh install.
- All 39 user-story acceptance checklists in spec §4 pass top to bottom.

---

## 10. Risks

- **AX brittleness on third-party Electron apps.** Out of v1 scope by design (spec §3 out-of-scope). Surface graceful failures rather than silent partial control.
- **`sandbox-exec` deprecation.** Wrapped behind `SandboxRunner` so the implementation can be swapped (per brief §8 / spec risk table). Low likelihood per brief.
- **Ollama latency on weaker hardware.** Default model is 7B Q4_K_M (per spec §6 #10); users on M-Pro/Max can opt into 14B. Some latency unavoidable.
- **macOS 26 deep-link drift.** `SystemSettingsLinks` constants will need re-verification during macOS 26 betas (per brief §12.5). Mitigated by fallback to parent Privacy & Security pane.
- **Web DOM fragility.** Ongoing maintenance cost; the per-adapter `waitForSelector` helper is the primary primitive against it (per brief §4, spec risk table). Not a one-time fix.
- **`ValidatedPlan` file-private init.** If the implementer ever splits `PlanValidator` across multiple files, the file-private gate breaks. Documented; the acceptance test (`T-P5-05` compile-fail) catches it if it regresses.
