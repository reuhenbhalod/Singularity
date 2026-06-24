# Singularity

**One-Line OS** — a fullscreen AI command shell for macOS. Hit a global
hotkey, type what you want in plain English, and the shell acts on it
directly (opening apps, playing content, driving websites) by routing
your intent through a **local** LLM planner into a multi-lane executor.

It is not a chatbot. It does not answer questions — it turns intent into
actions and performs them.

> **Status:** early development. Phases 0–3 are complete: the shell,
> the local-LLM planner, the input-safety boundary, and the executor's
> URL-scheme + web lanes. Today the reliable end-to-end flow is
> *"play the newest video from a YouTube channel"* — by the creator's
> name, not their exact handle; broader app control arrives in later
> phases. See `docs/plans/00-plan.md` for the roadmap and
> `CHANGELOG.md` for recent changes.

---

## Requirements

| Tool | Version | Why |
|------|---------|-----|
| macOS | 14 (Sonoma) or newer, Apple Silicon | Target platform |
| Xcode | 16 or newer | Swift 6 + synchronized-folder project format |
| [Ollama](https://ollama.com) | latest | Runs the local planner model |

There are **no third-party Swift packages** — opening the project is all
the dependency setup the code itself needs. The one external dependency
is Ollama (below).

---

## Setup (first time, ~10 minutes)

### 1. Clone the repo

```bash
git clone https://github.com/reuhenbhalod/Singularity.git
cd Singularity
```

### 2. Install Ollama and pull the planner model

The planner is a **local** language model served by Ollama at
`localhost:11434`. Nothing leaves your machine. The app expects the
model `qwen2.5-coder:7b-instruct-q4_K_M` (~4.7 GB download).

```bash
brew install ollama
brew services start ollama          # runs Ollama in the background, now and at login
ollama pull qwen2.5-coder:7b-instruct-q4_K_M
```

Verify it's up:

```bash
curl http://localhost:11434/api/tags   # should list qwen2.5-coder:7b-instruct-q4_K_M
```

> Without Ollama running, the app still launches but every command
> reports *"Can't reach the planner — is Ollama running?"*.

### 3. Open and run in Xcode

```bash
open Singularity.xcodeproj
```

Then press **Run** (⌘R). Xcode signs the app to run locally — if it asks
about a signing team, pick your personal team or leave it on automatic.

The app has **no Dock icon and no window** when it launches — it lives in
the background until you summon it.

---

## Using it

1. Press **⌥Space** (Option + Space) anywhere to summon the fullscreen
   shell on whatever screen your cursor is on.
2. Type a command and press **Return**.
3. Press **⌥Space** again (or **Esc**) to dismiss it. Dismissing clears
   the session and closes any open panes.

### Commands that work today

```
play mrbeast's newest video
play the latest video from veritasium
play marques brownlee's newest video        # resolves even though the handle is @mkbhd
play another mkbhd video in a new tab
```

The planner understands many phrasings of "play a channel's newest
video." You can name the creator however is natural — if the exact
`@handle` isn't obvious (e.g. *Marques Brownlee* → `@mkbhd`), the shell
resolves it through YouTube search automatically. Playing another video
**reuses the current pane** unless you explicitly ask for a new tab.
(You'll need to be logged into YouTube in the pane the first time; the
login then persists across launches.)

Anything the executor can't carry out yet is reported plainly in the log
("I couldn't handle that step") rather than failing silently.

---

## Running the tests

The default suite is deterministic and fast (it does **not** call the
live model):

```bash
xcodebuild test -scheme Singularity -destination 'platform=macOS'
```

The live integration tests that drive a real Ollama are **gated** so the
default suite stays reliable (a local model isn't perfectly
deterministic, especially under parallel test execution). To run them:

```bash
touch /tmp/singularity-live-tests
xcodebuild test -scheme Singularity -destination 'platform=macOS' \
  -parallel-testing-enabled NO
rm /tmp/singularity-live-tests
```

Lint and format (optional, used in development):

```bash
swiftlint
swift-format format -i -r Singularity SingularityTests
```

---

## Known limitations (early development)

- **Not a Q&A assistant.** It performs actions; it won't tell you the
  weather. Asking for information opens the relevant page rather than
  answering in text.
- **YouTube is the reliable path.** The planner's prompt only teaches
  the YouTube pattern by example, so other sites are hit-or-miss until
  more adapters/examples are added. Requests like "find the best monitor
  under $100" are research/judgment tasks that are intentionally out of
  scope for v1.
- **Autoplay nudge is flaky.** The newest video opens reliably, but the
  watch page doesn't always auto-start playback yet (tracked for polish).
- **Logins and permissions are per-machine.** Each person logs into
  YouTube/Gmail on their own machine; Accessibility/Automation/Full Disk
  Access grants (needed by later phases) are granted manually in System
  Settings.

---

## Project layout

```
Singularity/
  App/         entry point, NSWindow, global hotkey, lifecycle
  Shell/       command input, session log, command pipeline
  Compositor/  pane tiling and pane views
  Planner/     Ollama client, plan schema, system prompt, planner
  Executor/    router + lanes (URLScheme/, Web/)
  Safety/      input validator, secret scanner, rate limiter,
               URL policy, allowed domains, safety log
  Adapters/    per-app web adapters (YouTube, Gmail)
  Settings/    settings store
  Resources/   system prompt + plan schema
SingularityTests/   tests, mirroring the source tree
docs/               research brief, spec, and the implementation plan
```

`docs/plans/00-plan.md` is the source of truth for build progress, and
`CLAUDE.md` documents the project conventions.

---

## Troubleshooting

- **"Can't reach the planner — is Ollama running?"** → start Ollama
  (`brew services start ollama`) and confirm the model is pulled
  (`ollama list`).
- **The hotkey doesn't summon the shell** → make sure the app is
  actually running (it has no Dock icon); ⌥Space may also be claimed by
  another app like Spotlight/Alfred — quit that or rebind.
- **A web pane is blank** → the site may not be on the allowlist yet
  (only adapter-declared hosts can load), or you may need to log in.
