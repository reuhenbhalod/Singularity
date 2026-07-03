# Singularity — Tasks

The single place to see **what's done, what's left, and who owns it.**
v1 (Phases 0–7) is **code-complete: 326 tests passing.** What remains is (A)
two manual account/system grants, and (B) the post-v1 build roadmap.

Full detail: implementation plan `docs/plans/00-plan.md` (v1 tasks) and spec
`docs/specs/00-spec.md` §12 (post-v1 phases).

---

## A. Your turn — manual grants (no coding) 🧑‍🤝‍🧑 partner

These **cannot be done in code** — they need portal/System-Settings access.
Until they're done, both features degrade honestly (a clear message, no
crash).

- [ ] **Register the App ID + enable "Sign in with Apple"** *(unlocks real
  sign-in — plan task T-P7-01)*
  1. Sign in at <https://developer.apple.com/account> → **Identifiers**.
  2. Register (or edit) the App ID for bundle `com.reuhenbhalod.Singularity`.
  3. Check **Sign in with Apple**, save.
  4. Note the **Team ID** + **bundle ID** and paste them here / to me so the
     entitlement can be wired.
  - *Today:* the Sign in with Apple button appears but captures nothing.

- [ ] **Grant Full Disk Access to the built app** *(unlocks reading
  protected folders like Mail — plan task T-P6-14)*
  1. Build/run the app once (so it exists on disk).
  2. **System Settings → Privacy & Security → Full Disk Access**.
  3. Click **+**, add **Singularity.app**, toggle it **on**.
  - *Today:* file reads into protected folders show a "grant Full Disk
    Access" banner instead of succeeding.

---

## B. Build roadmap — post-v1 (specced in `docs/specs/00-spec.md` §12)

Ordered by leverage. Each unchecked box is a buildable slice.

### Phase 8 — Parameterized write actions *(do first — biggest unlock)*
One new **injection-safe** action that carries arguments unlocks a whole
class of "create/send" commands at once.
- [ ] Injection-safe parameterized `apple_script` action (args passed
  out-of-band, never string-interpolated) + safety/fuzz tests
- [ ] **US-WR-1** Send an email (preview + confirm + Touch ID)
- [ ] **US-WR-2** Create a calendar event
- [ ] **US-WR-3** Add a reminder
- [ ] **US-WR-4** Create a note
- [ ] **US-WR-5** Play a specific song (Apple Music / Spotify by name)

### Phase 9 — Broader reach
- [ ] **US-AD-1** More web adapters (Netflix, Twitch, GitHub, Apple Music
  web, Google Docs/Drive, …)
- [ ] **US-SYS-1** More system controls (Wi-Fi, Bluetooth, brightness,
  Focus/DND, screenshot, display sleep)
- [ ] **US-SAFE-9** Per-hook risk classes (unlocks confirm-gated ops like
  empty-Trash)
- [ ] **US-CLIP-1** Clipboard read/write
- [ ] **US-WIN-1** Window & app management (quit/hide/close/minimize)

### Phase 10 — Scheduling & triggers
- [ ] **US-SCHED-1** Time-based routines ("every weekday at 8am run morning")
- [ ] **US-SCHED-2** Event triggers (join Wi-Fi X, plug in power, …)
- [ ] **US-SCHED-3** Schedules tab + logging + global "pause automations"

### Phase 11 — Smarter routines
- [ ] **US-RT-7** Parameterized routines (`routine gh = open github.com/$1`)
- [ ] **US-RT-8** Conditional steps (small, auditable — not a full language)
- [ ] **US-RT-9** Controlled nesting (`run NAME` steps; cycles rejected)

### Phase 12 — Planner quality
- [ ] **US-P-4** Coverage beyond curated examples (bigger few-shot / capability retrieval)
- [ ] **US-P-5** Gated multi-step decomposition (each step validated/confirmed)

---

## What already works (v1, shipped)

Shell + hotkey · local Ollama planner · 5 executor lanes (URL / WKWebView /
Accessibility / AppleScript / Files+sandboxed-shell) · web adapters
(YouTube, Gmail, Spotify, Amazon, Google, Wikipedia, Reddit, X/LinkedIn) ·
AppleScript adapters (Mail, Calendar, Music, Finder, Notes, Reminders,
Safari, **System** — dark mode / volume / lock) · full safety pipeline ·
routines (macros) · 7-tab Settings (overlay over the shell) · Sign in with
Apple + Keychain · first-run onboarding · factory reset · latency
instrumentation.

Conventions & definition-of-done live in `CLAUDE.md`. Pick the top unchecked
box in a phase, build it to its spec acceptance, keep `Safety/` tests green.
