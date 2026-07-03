# Singularity

**One-Line OS** — a fullscreen AI command shell for macOS. Hit a global
hotkey, type what you want in plain English, and the shell acts on it
directly (opening apps, playing content, driving websites, reading and
sending mail, running files) by routing your intent through a **local** LLM
planner into a five-lane executor.

It is not a chatbot. It does not answer questions — it turns intent into
actions and performs them.

> **Status:** all eight build phases (0–7) are **code-complete** —
> **112 / 114 plan tasks done, 320 tests passing.** The two remaining tasks
> are account/system grants (see the callout below). See
> **[`docs/plans/00-plan.md`](docs/plans/00-plan.md)** for the task-by-task
> plan (source of truth for progress), **[`CLAUDE.md`](CLAUDE.md)** for the
> project conventions, and `CHANGELOG.md` for recent changes.

---

## ✅ Remaining before v1 ship — 2 tasks, and **my partner will do these**

Every code task is finished. The only two items left are **manual
account/system grants that cannot be done in code** — and **my partner is
handling both of them:**

- [ ] **T-P7-01 — Register the App ID + enable "Sign in with Apple"** in the
  Apple Developer portal, then record the team/bundle ID for the
  entitlements. Unlocks real sign-in. **← _partner_**
- [ ] **T-P6-14 — Grant Full Disk Access** to the built app in System
  Settings → Privacy & Security. Unlocks reading protected folders (e.g.
  Mail). **← _partner_**

Until then, both paths **degrade honestly**: the Sign in with Apple button
and protected-folder reads surface a clear reason instead of crashing.

---

## Requirements

| Tool | Version | Why |
|------|---------|-----|
| macOS | 14 (Sonoma) or newer, Apple Silicon | Target platform |
| Xcode | 16 or newer | Swift 6 + synchronized-folder project format |
| [Ollama](https://ollama.com) | 0.30+ | Runs the local planner model |

There are **no third-party Swift packages** — opening the project is all
the dependency setup the code itself needs. The one external dependency is
Ollama (below).

---

## Setup (first time, ~10 minutes)

### 1. Clone the repo

```bash
git clone https://github.com/reuhenbhalod/Singularity.git
cd Singularity
```

### 2. Install Ollama and pull the planner model

The planner is a **local** language model served by Ollama at
`localhost:11434`. Nothing leaves your machine. The app expects the model
`qwen2.5-coder:7b-instruct-q4_K_M` (~4.7 GB download).

```bash
brew install ollama
brew services start ollama          # runs Ollama in the background, now and at login
ollama pull qwen2.5-coder:7b-instruct-q4_K_M
```

Verify it's up:

```bash
curl http://localhost:11434/api/tags   # should list qwen2.5-coder:7b-instruct-q4_K_M
```

> Without Ollama running, the app still launches but every command reports
> *"Can't reach the planner — is Ollama running?"*.

### 3. Open and run in Xcode

```bash
open Singularity.xcodeproj
```

Then press **Run** (⌘R). Xcode signs the app to run locally — if it asks
about a signing team, pick your personal team or leave it on automatic.

> On some macOS 26 point releases the app can fail to launch with error
> **-10825** (deployment-target mismatch). If that happens, build from the
> CLI with the deployment target pinned:
> ```bash
> xcodebuild -scheme Singularity -configuration Debug build \
>   CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=26.3
> open ~/Library/Developer/Xcode/DerivedData/Singularity-*/Build/Products/Debug/Singularity.app
> ```

The app has **no Dock icon and no window** when it launches — it lives in
the background until you summon it. On first launch it shows a short
**onboarding window** (permissions checklist + optional Sign in with Apple
+ "Skip for now").

---

## Using it

1. Press **⌥Space** (Option + Space) anywhere to summon the fullscreen
   shell on whatever screen your cursor is on.
2. Type a command and press **Return**.
3. Press **⌥Space** again (or **Esc**) to dismiss it. Dismissing clears the
   session and closes any open panes.

Type **`settings`** to open the Settings window (or change the hotkey,
appearance, model, safety, routines, permissions, and account there).

### What you can do

**Web (opens a pane, executes inside it — login persists per machine):**
```
play mrbeast's newest video
play the latest video from veritasium
play marques brownlee's newest video        # resolves even though the handle is @mkbhd
play another mkbhd video in a new tab        # reuses the pane unless you ask for a new tab
open gmail                                    # Gmail web adapter
```

**Native apps (Apple-native via AppleScript; Spotify via Accessibility):**
```
play spotify   /   pause spotify             # Spotify (Accessibility lane)
open notes   /   create a note …             # Notes, Reminders, Calendar,
read my latest mail                          # Mail, Music, Finder, Safari
```

**Files & shell (tightly sandboxed, safety-gated):**
```
move ~/Downloads/report.pdf to ~/Documents   # FileManager move/copy/list
trash ~/Downloads/old.zip                     # goes to Trash, never hard-deleted → asks to confirm
```

**Routines (your own named macros):**
```
routine morning = open mail; play lofi beats; open calendar
morning                                       # invoke by bare name…
run morning                                   # …or explicitly
routines                                       # list them; edit/delete in Settings → Routines
```

**Local diagnostics (never hit the planner):**
```
axdump com.apple.finder                        # dump an app's Accessibility tree
/safety log                                    # recent safety-pipeline events
abort                                          # panic-stop the in-flight command
```

Anything the executor can't carry out is reported plainly in the log with a
reason ("I can't control X via AppleScript yet", "grant it in System
Settings → …") rather than failing silently.

### The safety pipeline (always on)

Every command passes through it, in order:
1. **Input boundary** — Unicode normalization (strips zero-width / bidi /
   control chars), a **credential scanner** (fails closed on AWS/GitHub/
   OpenAI/Slack/Stripe/Google keys, card numbers, SSNs — the raw input is
   never logged), a 4 KB cap, and a per-session rate limit.
2. **Routine resolution** — bare-name / `run NAME` only; never mid-sentence.
3. **Plan validation** — the planner's JSON is checked for content, not just
   shape: HTTPS-only + host allowlist, shell denylist (`curl … | sh`, base64
   -to-eval, `../` escapes), symlink-resolved file paths, and a taint check.
   The executor accepts **only** a type-gated `ValidatedPlan` — there is no
   other way to reach it.
4. **Risk gates** — Touch ID for destructive/spend actions, a plain-English
   **confirm preview** before anything mutating, and the Amazon checkout
   path has two hard stops.
5. **Untrusted-content envelope** — anything read from the web/AX/mail/files
   is wrapped so indirect prompt-injection can't smuggle instructions into
   the planner.

The **NSFW filter** (on by default, toggle in Settings → Safety) layers on
top of the allowlist; turning it off never widens the allowlist.

---

## Running the tests

The default suite is deterministic and fast (it does **not** call the live
model):

```bash
xcodebuild test -scheme Singularity -destination 'platform=macOS'
```

The live integration tests that drive a real Ollama are **gated** so the
default suite stays reliable (a local model isn't perfectly deterministic,
especially under parallel test execution). To run them:

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

## What's built (all phases)

| Phase | Delivered |
|------:|-----------|
| **0** | Fullscreen shell panel, global ⌥Space hotkey (Carbon, no Input-Monitoring TCC), session log, pane compositor |
| **1** | Hero command end-to-end (YouTube newest-video), hardcoded plan |
| **2** | Local Ollama planner: grammar-constrained JSON, one repair attempt then fail-loud, configurable |
| **3** | Executor router + URL-scheme lane + WKWebView lane (per-adapter data stores, allowlist nav delegate) |
| **4** | Accessibility lane + AX wrappers; Spotify + Mail AX adapters; permissions manager |
| **5** | **Safety pipeline** (type-gated `ValidatedPlan`, Touch ID/confirm gates, injection envelope, NSFW, panic phrase, `SafetyLog`) |
| **6** | AppleScript lane + Mail/Calendar/Music/Finder/Notes/Reminders/Safari adapters; Files lane (move/copy/list/trash + staging) + `sandbox-exec` shell |
| **7** | Routines (macros), 7-tab Settings, Sign in with Apple + Keychain identity, first-run onboarding, permission banners, factory reset, OSLog viewer, latency instrumentation |

**Latency (measured, Apple Silicon):** hotkey-to-focus < 150 ms · command
overhead excluding the model a few ms · hero command end-to-end ~2 s (budget
5 s) · Settings open < 200 ms.

### Known limitations

- **Not a Q&A assistant.** It performs actions; it won't tell you the
  weather. Asking for information opens the relevant page.
- **Web adapters are curated.** YouTube is the most exercised path; Gmail,
  Spotify-web, and Amazon adapters exist. Sites outside the allowlist won't
  load. Open-ended research ("best monitor under $100") is out of scope for
  v1 by design.
- **Native control depends on grants.** Accessibility and Automation prompts
  appear on first use; a denied permission disables only that lane and
  surfaces a banner. Spotify's AX tree (Chromium-embedded) can be sparse.
- **Logins & permissions are per-machine**, and the two grants in the
  callout above are still pending.

---

## Building on this (for contributors)

- **[`CLAUDE.md`](CLAUDE.md)** is the law for this project — stack,
  structure conventions (one primary type per file, folder-per-module),
  error-handling and concurrency rules, the testing bar, and the "definition
  of done" every change must meet. Read it first.
- **[`docs/plans/00-plan.md`](docs/plans/00-plan.md)** is the ordered task
  list; the acceptance walk and latency results are recorded in its §8.
- `docs/research/` and `docs/specs/` hold the research brief and the v1 spec
  the plan was derived from.
- **Definition of done** (per `CLAUDE.md`): the acceptance check passes,
  tests exist and pass under `xcodebuild test`, and `swiftlint` +
  `swift-format` are clean. Anything touching `Safety/` must keep its tests
  green — that's non-negotiable.

---

## Project layout

```
Singularity/
  App/         entry point, NSWindow, global hotkey, lifecycle
  Shell/       command input, session log, command pipeline, permission banner
  Compositor/  pane tiling and pane views
  Planner/     Ollama client, plan schema, system prompt, planner
  Executor/    router + five lanes:
               URLScheme/, Web/, Accessibility/, AppleScript/, Files/
  Safety/      input validator, secret scanner, rate limiter, plan validator,
               URL policy, allowed domains, NSFW blocklist, untrusted-content
               envelope, risk/auth/confirm gates, panic controller, safety log
  Adapters/    Web/ (YouTube, Gmail, Spotify, Amazon),
               AppleScript/ (Mail, Calendar, Music, Finder, Notes, Reminders,
               Safari), Accessibility/ (Spotify, Mail)
  Routines/    routine model, store, parser, resolver, inline command handler
  Permissions/ TCC state (Accessibility/Automation/Full Disk) + Settings links
  Identity/    IdentityRecord + Keychain store, AccountModel, credential check
  FirstRun/    onboarding flow, view, and window controller
  Settings/    settings store + 7 tabs, factory reset, hotkey/login/appearance
  Diagnostics/ latency instrumentation (signposts + OSLog)
  Resources/   system prompt + plan schema + NSFW blocklist
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
- **The hotkey doesn't summon the shell** → make sure the app is actually
  running (it has no Dock icon); ⌥Space may also be claimed by another app
  like Spotlight/Alfred — quit that, or rebind in Settings → General.
- **A web pane is blank** → the site may not be on the allowlist yet (only
  adapter-declared hosts load), or you may need to log in.
- **"I need permission to control X"** → grant Accessibility / Automation in
  System Settings → Privacy & Security (the Permissions tab deep-links to
  the right pane).
- **App won't launch (error -10825)** → build with
  `MACOSX_DEPLOYMENT_TARGET=26.3` (see Setup step 3).
