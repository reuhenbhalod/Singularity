# Project conventions

This file loads at the start of every session and is inherited by every agent in
the build pipeline. The values below are the law for this project; change them
deliberately, not casually.

## What this project is

One-Line OS (working title: Singularity) is a fullscreen AI command shell for
macOS. The user hits a global hotkey, types intent in plain English, and the
shell acts on it directly — opening apps, playing content, reading and answering
mail — by routing intent through a local Ollama planner into a five-lane
executor waterfall (URL scheme, WKWebView, Accessibility API, AppleScript,
FileManager + sandboxed shell). It is not a chatbot. It is the interface.

Full concept and architecture: see `Singularity.md` in the project root.

## Stack

- Language and version: Swift 6 (Swift Testing-ready), targeting macOS 14+
  (Sonoma) and above. Apple Silicon is the assumed runtime.
- UI: SwiftUI for views, AppKit interop (`NSWindow`, `NSEvent` global monitor)
  for the fullscreen shell window and global hotkey.
- IDE / build: Xcode 16 or newer. Project lives at `Singularity.xcodeproj`.
- Local intelligence: Ollama (HTTP at `localhost:11434`), Qwen2.5-Coder as the
  default planner model. Treated as an external service, not bundled.
- macOS APIs used directly: `NSWorkspace`, `WKWebView` + `evaluateJavaScript`,
  Accessibility (`AXUIElement` from `ApplicationServices`), AppleScript / JXA
  (via `NSAppleScript` / `OSAScript`), `FileManager`, `Process`, `sandbox-exec`.
- No third-party Swift packages in v1 unless a phase plan explicitly justifies
  one. Keep the dependency surface small.

## Commands

Run from the project root.

- Install: `xcodebuild -resolvePackageDependencies` (no-op until SPM deps exist)
- Run dev: open `Singularity.xcodeproj` in Xcode and Run, or
  `xcodebuild -scheme Singularity -configuration Debug build && \
   open build/Debug/Singularity.app`
- Test: `xcodebuild test -scheme Singularity -destination 'platform=macOS'`
- Lint: `swiftlint` (config at `.swiftlint.yml`)
- Format: `swift-format format -i -r Singularity SingularityTests`
- Type check: covered by `xcodebuild build` (Swift compiler is the type checker)

If a command above does not yet exist, the implementer adds the supporting
config in the phase that needs it, rather than silently skipping the step.

## Conventions

- **Structure** (under `Singularity/`):
  - `App/` — entry point, `NSWindow` setup, global hotkey, app lifecycle.
  - `Shell/` — command input, ephemeral session log, top-level shell view.
  - `Compositor/` — pane layout engine and pane container views.
  - `Planner/` — Ollama HTTP client, JSON schema, plan types, retry/repair.
  - `Executor/` — router plus one subfolder per lane
    (`URLScheme/`, `Web/`, `Accessibility/`, `AppleScript/`, `Files/`).
  - `Safety/` — policy checker, risk classifier, confirm-gate UI, APFS snapshot
    wrapper, injection filter.
  - `Adapters/` — per-app web and native adapters (one file per app).
  - Tests live in `SingularityTests/`, mirroring the source folder tree.
- **Naming**: types `PascalCase`, methods and properties `camelCase`, one
  primary type per file, file named after the type. Folder names match the
  module concept in PascalCase.
- **Error handling**: use `throws` with typed errors at boundaries (Ollama,
  filesystem, web, AX, AppleScript). Never `try?` to silence; if a failure is
  expected and ignorable, comment why. No `fatalError` in production paths
  outside of programmer-error invariants.
- **Concurrency**: Swift concurrency (`async`/`await`, actors). UI work on
  `@MainActor`. Long-running executor work off the main actor.
- **Tests**: Swift Testing (`@Test`) preferred for new code; XCTest accepted
  where Swift Testing does not yet cover the surface (e.g. some UI tests).
  Colocate by mirror path under `SingularityTests/`. Safety pipeline tests are
  non-negotiable for any change touching `Safety/`.
- **Logging**: `os.Logger` with a per-subsystem category. No `print` in shipped
  code.
- **Secrets**: none should exist in v1 (the planner is local). If any external
  API key is ever needed, it lives in a gitignored `.env` and is loaded via the
  app's keychain — never committed.

## Explain as you go (teaching mode)

I am learning as this project gets built, so narrate the work. This applies to
every agent in the pipeline and every action they take.

- Before running any command, say what the command does and why you are running
  it at this point. One or two plain-language sentences is enough.
- Before building or changing a piece of code, explain what you are about to
  build, why this approach, and what the main alternative was if there was a
  real choice. Keep the trade-off short but concrete.
- After a command runs, briefly interpret the output. Don't just paste the
  result; tell me what it means and what it implies for the next step. If
  something failed, explain the likely cause in terms I can learn from.
- When you introduce a tool, library, pattern, or concept I may not know, give
  a one-line definition the first time it appears.
- Favor teaching over speed. A few sentences of "here's what and why" on each
  step is the goal, not a wall of text. If an explanation would be long, give
  me the short version and offer to go deeper.
- This is about clarity, not permission. Explaining a step is not a request to
  confirm it unless the action genuinely needs my sign-off.

## Definition of done

A task is done when:
- It meets its acceptance check in the plan and the related spec criteria.
- Tests for the change exist and pass under `xcodebuild test`.
- Lint (`swiftlint`), format (`swift-format`), and type check
  (`xcodebuild build`) are clean.
- No secrets or keys are committed.
- Any new lane, adapter, or destructive code path is wrapped by the safety
  pipeline or has an explicit, recorded justification for why it does not need
  to be.

## Build pipeline artifacts

This project uses a staged build pipeline driven by the `/build` command. Stage
outputs live here and are the handoff between agents:

- Research briefs: `docs/research/`
- Specs: `docs/specs/`
- Implementation plans: `docs/plans/`

The plan's task checklist is the source of truth for build progress.

Pacing: this project pauses at every gate. After research, after spec, after
plan, and between each implementation task, work stops for human review before
the next step starts.

## Off-limits

Do not modify without explicit instruction:
- `Singularity.xcodeproj/project.pbxproj` outside of normal Xcode-driven edits
  (no hand-editing the project file to add files; let Xcode do it, or use
  XcodeGen if introduced in a phase plan).
- TCC permission state. The user grants Accessibility, Automation, and Full
  Disk Access manually in System Settings; never attempt to script `tccutil`
  resets or work around the consent dialogs.
- Anything inside `~/Library/`, `/System/`, or other system directories during
  development. The sandboxed shell lane is the only thing allowed to touch
  filesystem paths, and only inside its declared scope.
- The two root design documents (`Singularity.md`, this `CLAUDE.md`) — propose
  edits in a message and wait for approval before changing them.
