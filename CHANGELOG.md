# Changelog

Notable changes to Singularity. The overall build follows the phase
roadmap in `docs/plans/00-plan.md`; entries here capture hardening and
polish done within and around those phases. Newest first.

## [Unreleased] — 2026-06-23

Web-lane hardening, name-based channel resolution, context-aware panes,
and a UI refresh. No new third-party dependencies; no project-file
changes (source files are picked up via Xcode's synchronized folders).

### Added
- **Play a creator by name — no exact handle needed.** When a guessed
  `@handle` misses (e.g. *Marques Brownlee* → `@mkbhd`), the web lane
  resolves the creator through YouTube's own channels search, opens the
  real channel, and plays its newest video.
- **Shared web-automation toolkit** (`Adapters/Web/WebHookJS.swift`):
  reusable, robustness-first JS primitives every adapter can compose —
  `firstLinkMatching` (select by stable URL shape), `waitForSelector`,
  `clickByText`, `dismissConsent`, and safe string escaping.
- **Context-aware panes.** Same-site navigations reuse the open pane;
  the planner sets `new_pane` only when the user explicitly asks for a
  new tab/window ("in a new tab", "side by side").
- **Rotating empty-state suggestion.** The idle shell shows a different
  (and real, working) command on every summon, doubling as onboarding.
- **`ShellStyle`** — a small shared visual language (accent, text tiers,
  surfaces, metrics) so the command line, log, and panes stay consistent.

### Changed
- **Robust YouTube video finding.** The newest video is located by the
  stable `/watch?v=` URL shape rather than brittle DOM ids that YouTube
  renames; a consent wall (if present) is dismissed first.
- **Planner prompt** now forms channel handles correctly from possessive
  phrasings ("the stradman's" → `@TheStradman`).
- **Auto-focus on summon** — keyboard focus is taken (and re-asserted
  after the panel becomes key) so you can type without clicking.
- **UI polish** across the command line (accent prompt, larger type),
  session log (clearer glyphs, selectable text), and pane chrome; the
  log strip stays hidden until there is output.

### Fixed
- **"4 tabs of the same channel."** Re-issuing a command during a slow
  page load no longer spawns duplicate panes — the pane is registered as
  current *before* the navigation `await`, so a rapid retry reuses it.
- **Possessive handles** ("the stradman's") that produced dead channel
  URLs and a "couldn't find a video" result.

### Tests
- 180 unit tests pass (Swift Testing). Added coverage for the search
  fallback, same-site pane reuse, the rapid-reissue race, `new_pane`
  encode/decode, and the shared web toolkit.

### Developer notes
- **Ollama ≥ 0.30 is required on macOS 26 (Tahoe).** Earlier versions
  crash the GGML Metal backend when loading the planner model.
- The project's macOS deployment target is **26.4**; to run on an earlier
  OS, lower *macOS Deployment Target* in the Singularity target's Build
  Settings (the docs otherwise target macOS 14+).
