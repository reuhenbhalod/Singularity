# One-Line OS

*An AI command shell for macOS — you speak intent, the computer acts.*

Working title. This document captures the concept, scope, architecture, and build plan as designed so far.

---

## 1. Concept

One-Line OS replaces the traditional point-and-click interface with a single command line. You hit a global hotkey, the shell fills the screen, you type what you want in plain language, and it happens — apps open, content plays, emails get read and answered — without you clicking around.

It is not a chatbot. There is no conversation, no personality, no persistent memory. It is a command interface: speak intent, the OS acts, and the result renders inside the shell as a pane. Think of it as a terminal that understands English and has hands.

It runs as a layer on top of macOS, not a bootable kernel. macOS is the kernel it borrows — the real Finder and apps still exist underneath, which means the fallback if anything breaks is free: you can always drop back to normal macOS.

### Example commands

- "Open Spotify and play my most recently listened-to song."
- "Open YouTube and play MrBeast's newest video."
- "Open Gmail, read me the most recent email, and draft a response."
- "Order the Sony WH-1000XM5 headphones on Amazon."

In each case the shell takes over the screen, opens the relevant app or site inside its own canvas, and performs the action immediately.

---

## 2. Principles

1. **It owns the screen.** When open, the shell fills the display. Apps and content render *inside* it as tiled panes, not as separate macOS windows you click between.
2. **Immediate, not assistive.** When you ask for something, it does it. It is not a tool that drives your existing cursor around the screen — it is the interface itself.
3. **Panes tile.** Open two things and they sit side by side. Open five and you get five. The line manages them.
4. **No memory.** The session log is ephemeral and resets when you close the shell, like a terminal.
5. **Local-first intelligence.** Intent parsing runs locally on the machine for privacy and offline capability.
6. **Safety scales with consequence.** Reading an email is free. Spending money or deleting files is gated.

---

## 3. Scope

### In scope (v1)

- A fullscreen SwiftUI shell with a command line and a tiling pane compositor.
- Web apps driven inside embedded browser panes (YouTube, Spotify Web, Gmail, etc.).
- Native apps driven through the macOS Accessibility API (read their UI, click elements, fill fields).
- Apple-native apps controlled through their AppleScript dictionaries.
- File operations through native macOS APIs.
- A shell catch-all for anything else.
- A safety pipeline gating every destructive or irreversible action.

### Out of scope (v1)

- Driving third-party native apps that have no URL scheme, no AppleScript dictionary, no web version, and no CLI. These exist but are a small minority; v1 handles them with a graceful "I can open this but can't complete that automatically yet."
- Vision / screenshot-based control. Explicitly rejected as too slow and unreliable — the Accessibility API replaces it entirely.
- Persistent memory and cross-session state.

---

## 4. Architecture

The system is one downward flow with a single clever piece in the middle.

```
        Command line          you type intent, shell owns the screen
             |
      Ollama intent planner    local model, outputs a structured JSON plan
             |
       Executor router         reads the plan, picks a lane
             |
   ┌─────────────────────────────────────────┐
   │  Executor waterfall  (first match wins)  │
   │    1. URL scheme        instant launch   │
   │    2. WKWebView + JS     web apps         │
   │    3. Accessibility API  native app UI    │
   │    4. AppleScript / JXA  Apple apps       │
   │    5. FileManager + zsh  files, catch-all │
   └─────────────────────────────────────────┘
             |
   Safety pipeline   policy check -> risk classifier -> confirm gate
             |
      Pane compositor          tiles the result into the shell
             |
          macOS                NSWorkspace, WKWebView, AX API, sandbox-exec
```

### The key insight: the executor waterfall

The router does **not** write or run freeform code. It classifies which lane a command belongs to and tries the lanes in priority order — fastest and safest first. The model picks a lane, not a program. That single decision is what turns "let an LLM control my Mac" from a research problem into ordinary engineering.

A command falls through the waterfall until a lane can handle it:

1. **URL scheme** — many apps register schemes (`spotify:playlist:...`, `vscode://`, etc.). Constructing a URL and calling `NSWorkspace.open` is instant and zero-fragility. First choice whenever it applies.
2. **WKWebView + JS injection** — for any web app. Navigate an embedded browser pane to the site, then call `evaluateJavaScript` to read content, fill forms, and click. Reliable because it calls the DOM directly rather than simulating a human.
3. **Accessibility API** — for native apps with no web version. Every UI element exposes itself as an `AXElement` in a structured tree you can read and act on (`.press()`, `.setValue()`). No screenshots, no vision model — structured queries against the real UI. Requires per-app navigation logic.
4. **AppleScript / JXA** — for Apple-native apps (Mail, Calendar, Music, Finder, Messages) and third-party apps that ship a scripting dictionary. A structured API, not UI simulation.
5. **FileManager + zsh** — native Swift file operations for anything on disk, with a sandboxed shell subprocess as the universal catch-all.

---

## 5. Components

### Command line and shell
A fullscreen `NSWindow` summoned by a global hotkey. Holds the command input, an ephemeral session log, and the pane compositor.

### Session log
The running log of what you typed and what the OS did. Held in memory, rendered above the line, and discarded when the shell closes. Doubles as short-term context within a single session and as a live audit trail.

### Pane compositor
Tiles the open panes side by side. Each web pane is a `WKWebView`; native results render in custom panes (a file view, a reader, etc.). The line manages panes — open, close, swap, focus.

### Intent planner (Ollama)
A local model (Qwen2.5-Coder recommended) reachable at `localhost:11434`. Takes the raw command and a tight system prompt, and returns a strict JSON action plan. Structured output is non-negotiable — it must be parseable, not freeform prose.

### Executor router
Reads the JSON plan and dispatches to the waterfall, trying lanes in priority order.

### Safety pipeline
Wraps execution of any mutating action (see below).

---

## 6. Safety pipeline

Read-only, reversible actions (open an app, play a song, read an email) flow straight through. The moment a command touches files, runs shell code, or spends money, it passes through the gates:

1. **Policy check** — static analysis on any generated command. Rejects broad `rm -rf`, writes outside the declared scope, `sudo`, system-directory edits, and unexpected network calls before anything runs.
2. **Risk classifier** — tags each step read / reversible / destructive.
3. **Confirm gate** — destructive or irreversible steps show a plain-English preview ("move 14 files, delete 0") and wait for explicit confirmation. No auto-proceed.
4. **APFS snapshots** — a local snapshot is taken before any risky mutation, giving filesystem-level rollback.
5. **Injection filter** — everything the OS *reads* (file contents, web pages, emails) is treated as untrusted data, never as instructions. Zero-width and control unicode are normalized out before content enters the model context. Fetched content can never, by itself, authorize a destructive action.

The Amazon purchase flow is the extreme case: two hard confirm stops — one before adding to cart, one before placing the order — and neither auto-proceeds regardless of how confident the intent parser is.

---

## 7. macOS substrate and permissions

The OS borrows a small set of native capabilities:

- `NSWorkspace` — launch and manage apps.
- `WKWebView` — embed and drive web content inside panes.
- Accessibility API (`AXUIElement`) — read and control native app UIs.
- AppleScript / JXA — structured app automation.
- `FileManager` and `Process` — file operations and the sandboxed shell.
- `sandbox-exec` — scoped subprocess execution for generated code.

Required TCC permissions, granted once by the user: Accessibility, Automation, and Full Disk Access.

---

## 8. Build plan

Core principle: **vertical slice first.** Get one command working end-to-end before building breadth, keep the app runnable at every phase, and put the safety pipeline in place before anything can touch files or run code.

### Phase 0 — Shell skeleton
Xcode project, SwiftUI macOS app. Fullscreen window, global hotkey to summon/dismiss, the command line input, the ephemeral log strip, and the empty pane compositor. Nothing executes yet.
→ *Milestone:* app launches fullscreen, you can type, empty panes can be added and removed.

### Phase 1 — Hero command, hardcoded
Build the reusable `WKWebView` pane and wire the compositor to tile them. Hardcode the YouTube flow with simple string matching (no Ollama yet): open a pane, navigate to the channel, inject JS to find and play the newest video.
→ *Milestone:* "play mrbeast newest video" actually opens YouTube in a pane and plays. Proves the hardest-looking part is the easy part.

### Phase 2 — Intent engine
Integrate Ollama via its local HTTP API. Write the system prompt and a strict JSON schema, swap the string matcher for Ollama → JSON plan, and handle malformed output with a re-prompt and fallback.
→ *Milestone:* varied phrasing all resolves to the same plan. Retires the biggest reliability risk early.

### Phase 3 — Router and the easy lanes
Build the executor router. Implement lane 1 (URL schemes via `NSWorkspace.open`) and generalize Phase 1 into a reusable lane 2 (`WKWebView` + JS, with per-site adapters).
→ *Milestone:* multiple web apps and instant native launches flow through one router.

### Phase 4 — Native app control
Request Accessibility permission, then build the `AXUIElement` traversal helpers (find by role/title, `.press()`, `.setValue()`) and the first per-app adapters (Spotify native, Mail/Gmail).
→ *Milestone:* "read my latest email and draft a reply" works on a real native app. Retires the second risk.

### Phase 5 — Safety pipeline
Build before enabling any shell or file execution. Policy checker, risk classifier, confirm-gate UI, APFS snapshot wrapper, and the injection filter.
→ *Milestone:* every mutating action routes through the gates; destructive ops require confirmation.

### Phase 6 — System and file lanes
With the gates live, add lane 4 (AppleScript/JXA) and lane 5 (`FileManager` plus a sandboxed zsh catch-all).
→ *Milestone:* file operations and arbitrary shell work, all gated.

### Phase 7 — Daily-driver polish
Multi-pane management from the line, graceful fallbacks for unsupported commands, adapter-library expansion with a maintenance pattern for fragile web DOM, and latency tuning.
→ *Milestone:* usable as a real interface, not a demo.

Phases 0–3 are the spine and very achievable solo. Phase 4 is where the real engineering depth lives. Everything after is breadth and hardening.

---

## 9. Risks

| Risk | Where it lives | Mitigation |
| --- | --- | --- |
| Ollama JSON reliability | Intent planner | Strict schema, re-prompt on malformed output, code-strong local model. Killed early in Phase 2. |
| Accessibility API brittleness | Native app lane | Per-app adapters, deterministic once written. Validated in Phase 4. |
| Web DOM fragility | WKWebView lane | Resilient selectors that target semantic structure (button text) over generated class names; curated, maintained adapter list. Ongoing cost, not a one-time fix. |
| Ollama latency on weaker hardware | Intent planner | Code-strong small model; acceptable on Apple Silicon with adequate unified memory. Partly a hardware dependency. |
| The long tail of commands | Whole system | Define the supported vocabulary clearly; fail gracefully rather than silently on the unsupported. |

The first two risks are deliberately retired in Phases 2 and 4 — you find out early whether they are tractable before sinking weeks into breadth. The third never fully dies; it is a maintenance cost you manage, not a problem you solve once.

---

## 10. Tech stack

- **Language / UI:** Swift, SwiftUI, with AppKit interop for the window and global hotkey.
- **Web panes:** `WKWebView` + `evaluateJavaScript`.
- **Native control:** Accessibility API (`ApplicationServices` / `AXUIElement`), AppleScript / JXA.
- **System:** `Foundation` (`FileManager`, `Process`), `NSWorkspace`, `sandbox-exec`.
- **Intelligence:** Ollama (local), Qwen2.5-Coder.
