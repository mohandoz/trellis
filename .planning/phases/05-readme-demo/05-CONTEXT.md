# Phase 5: README Demo - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Create a self-contained `scripts/record-demo.sh` that records an automated
asciinema session of `conjure init --dry-run --profile=ts-next .` followed by
`conjure audit` in an isolated temp dir, converts the recording to a GIF via
`agg`, and commits the result to `.github/assets/demo.gif`. Embed the GIF in
`README.md` inside the Quickstart section (replacing the existing code block)
with a short italic caption. Add a CI check that asserts `demo.gif` exists
and is non-empty.

Requirements: DOCS-01.

</domain>

<decisions>
## Implementation Decisions

### Demo Content
- **D-01:** Profile: `ts-next` — widest audience recognition, best-case
  scaffold output.
- **D-02:** Sequence: `conjure init --dry-run --profile=ts-next .` then
  `conjure audit`. No preflight step — starts directly at init.
- **D-03:** Target length: under 60 seconds. Init dry-run output + audit
  pass in ~45s at normal simulated typing speed.

### Reproducibility
- **D-04:** `scripts/record-demo.sh` is committed. It:
  1. Creates an isolated `mktemp -d` temp dir (no leakage to real `$HOME`).
  2. Runs the command sequence via an `expect` script (automated, deterministic
     typing — not manual).
  3. Wraps everything in `asciinema rec` to capture the session.
  4. Calls `agg` to convert the `.cast` file to a GIF.
  5. Copies the GIF to `.github/assets/demo.gif`.
- **D-05:** The `expect` automation means every re-recording is byte-identical
  in content (same commands, same simulated typing delays). Matches the roadmap
  success criterion "reproducible from a documented command."

### Conversion Toolchain
- **D-06:** Toolchain: `asciinema` (recorder) → `agg` (official GIF converter,
  Rust-based). No `termtosvg` (unmaintained). No SVG embed path.
- **D-07:** Output artifact: `.github/assets/demo.gif`. Consistent with
  existing `.github/assets/logo.svg`. Git-tracked, no external hosting.
- **D-08:** CI check: assert `test -s .github/assets/demo.gif` (file exists
  and is non-empty). Added to existing CI job — not a new job.

### README Placement
- **D-09:** Demo replaces the existing Quickstart code block. New reader
  sees the recording before reading any instructions — highest-impact placement.
- **D-10:** Caption: short italic below the GIF, e.g.,
  *`conjure init --dry-run --profile=ts-next .` — zero mutations, fully auditable.*
  Gives context without adding prose bulk.

### Claude's Discretion
- Exact `expect` delay timings between keystrokes (should feel natural, not
  rushed, within the <60s target).
- Whether to add a `# Re-record the demo` heading comment in `record-demo.sh`
  or keep it purely functional.
- Exact width/height passed to `agg` (standard terminal width 120 cols).
- Whether to strip the `expect` dependency from the CI check or just document
  it as a contributor-only tool.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Docs — DOCS-01 (the single requirement this phase addresses)
- `.planning/ROADMAP.md` §Phase 5 — Goal, success criteria, and phase boundary

### Existing Assets to Study
- `README.md` §Quickstart (lines ~63–76) — the existing code block that the
  demo GIF replaces; understand current structure before editing
- `.github/assets/logo.svg` — confirms `.github/assets/` is the correct home
  for `demo.gif`; follow same directory convention
- `scripts/regen-fixtures.sh` — example of an existing reproducibility helper
  script; follow its style for `scripts/record-demo.sh`

### Prior Phase Context
- `.planning/phases/04-regression-suite-dry-run-proof/04-CONTEXT.md` — D-04/D-05:
  `sandbox_setup` pattern (temp dir + trap); `record-demo.sh` should use the
  same isolated-temp-dir approach, NOT `sandbox_setup` directly (different purpose)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/regen-fixtures.sh` — style reference for `scripts/record-demo.sh`
  (POSIX bash, preflight-style commentary, single-purpose script)
- `tests/lib/sandbox.sh` `sandbox_setup()` — pattern: `mktemp -d` + `trap 'rm -rf' EXIT`;
  `record-demo.sh` should manage its own temp dir the same way

### Established Patterns
- `.github/assets/` — already used for `logo.svg`; `demo.gif` goes here
- CI job structure in `.github/workflows/ci.yml` — existing `test` and
  `audit-on-fixture` jobs; `demo.gif` check added to existing job, not a new one
- `scripts/` convention: POSIX bash 3.2+, shebang `#!/usr/bin/env bash`, no
  bash 4+ features

### Integration Points
- `README.md` Quickstart section (line ~63) — `## 🚀 Quickstart` heading;
  existing code block (```` ``` ````…```` ``` ````) replaced by GIF + caption
- `.github/workflows/ci.yml` — `test` job; add `test -s .github/assets/demo.gif`
  check to the existing steps

</code_context>

<specifics>
## Specific Ideas

- Caption text locked: *`conjure init --dry-run --profile=ts-next .` — zero
  mutations, fully auditable.* (from discussion; don't freelance a different
  caption)
- `expect` automation makes the recording deterministic — downstream agents
  should use `expect`/`autoexpect` for the scripted typing, not a here-doc
  piped into a shell

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 5-README Demo*
*Context gathered: 2026-05-25*
