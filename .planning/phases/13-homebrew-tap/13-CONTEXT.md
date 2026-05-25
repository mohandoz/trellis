# Phase 13: Homebrew Tap - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Publish Conjure as a Homebrew tap so macOS/Linux developers can install via
`brew install mohandoz/conjure/conjure` and receive automatic SHA updates on
every GitHub release.

Delivers:
- `Formula/conjure.rb` — Homebrew formula template committed to this repo; also
  bootstrapped into the separate `mohandoz/homebrew-conjure` tap repo
- `CONJURE_HOME` Homebrew auto-resolution — wrapper or cli/conjure conditional
  so `$(brew --prefix)/share/conjure/` is picked up without manual env config
- `.github/workflows/release.yml` updated — adds `mislav/bump-homebrew-formula-action@v3`
  step to auto-update SHA256 in the tap repo after each release
- BREW regression tests in `tests/run.sh` and VALIDATION.md

Does NOT introduce Docker (Phase 14), release-pipeline gate (Phase 15), Windows CI,
or multi-arch builds.

</domain>

<decisions>
## Implementation Decisions

### Homebrew Formula Location (BREW-01, BREW-03)
- **D-01:** Formula file lives at `Formula/conjure.rb` in THIS repo (mohandoz/conjure).
  The tap repo `mohandoz/homebrew-conjure` is a separate GitHub repo that only
  contains `Formula/conjure.rb`. The bump action copies/PRs the updated formula there.
- **D-02:** Formula references a tagged tarball URL (`https://github.com/mohandoz/conjure/archive/refs/tags/v<VERSION>.tar.gz`)
  + SHA256. Never a branch HEAD. Enforced by BREW-03.

### CONJURE_HOME Resolution (BREW-02)
- **D-03:** In `cli/conjure`, change the hard-coded CONJURE_HOME assignment from:
  `CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"`
  to a conditional that respects an already-set env var:
  `CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"`
  This lets the Homebrew formula wrapper set CONJURE_HOME before invoking the script.
- **D-04:** The formula installs a wrapper script at `bin/conjure` that exports
  `CONJURE_HOME="#{share}/conjure"` before exec-ing the real `cli/conjure`. No
  changes to cli/conjure beyond D-03. Pattern: standard Homebrew generated_binary pattern.
- **D-05:** Do NOT call `brew --prefix` inside `cli/conjure` at runtime — it adds ~200ms
  per invocation and requires brew to be on PATH. Wrapper approach is zero-overhead.

### Formula Install Layout (BREW-01, BREW-02)
- **D-06:** Formula installs to:
  - `bin/conjure` — wrapper script (sets CONJURE_HOME, execs real binary)
  - `share/conjure/cli/conjure` — real CLI dispatcher
  - `share/conjure/` — all runtime dirs: `profiles/`, `compliance/`, `migrations/`,
    `templates/`, `lib/`, `scripts/`, `VERSION`
  Not installed: `tests/`, `.planning/`, `.github/`, `CHANGELOG.md`, `Formula/`.

### Auto-Bump Action (BREW-04)
- **D-07:** `mislav/bump-homebrew-formula-action@v3` fires in `.github/workflows/release.yml`
  after the existing "Create release" step. It needs a `HOMEBREW_TAP_GITHUB_TOKEN`
  secret with `repo` write access to `mohandoz/homebrew-conjure`.
- **D-08:** Bump action config: `formula-name: conjure`, `homebrew-tap: mohandoz/homebrew-conjure`,
  `download-url: https://github.com/mohandoz/conjure/archive/refs/tags/${{ github.ref_name }}.tar.gz`.
  **Correction:** The action input is `homebrew-tap:` NOT `tap-repo:` — verified against
  `action.yml` in RESEARCH.md Pitfall 2; `tap-repo:` is silently ignored and defaults to Homebrew/homebrew-core.

### Claude's Discretion
- Exact Ruby DSL idioms in `conjure.rb` (test block, depends_on, etc.)
- Whether bump action uses `commit-message:` override or default format
- Whether VALIDATION.md test for BREW-01 is automated (formula syntax check) or documented as manual
- shellcheck exemption patterns needed for any new bash in formula wrapper (inline shell in Ruby heredoc is not shellchecked by CI)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and success criteria
- `.planning/REQUIREMENTS.md` §"Homebrew Tap" — BREW-01 through BREW-04
- `.planning/ROADMAP.md` §"Phase 13: Homebrew Tap" — 4 success criteria and phase goal

### Existing code to read before implementing
- `cli/conjure` lines 1-15 — CONJURE_HOME self-resolution (the one line to make conditional; D-03)
- `.github/workflows/release.yml` — existing release job to extend with bump step (D-07)
- `cli/conjure` lines 30-35 — `cmd_version()`: must still work after CONJURE_HOME change (reads `$CONJURE_HOME/VERSION`)
- `scripts/preflight.sh` — confirm CONJURE_HOME used consistently (no hard-coded paths)
- `tests/run.sh` lines 1-30 — existing test block structure for BREW assertions
- `.planning/phases/12-org-overlay/12-VALIDATION.md` — VALIDATION.md format to follow

### Write chokepoint (invariant)
- `lib/mutate.sh` — any new filesystem writes in install-related scripts must use mutate_*
- Formula is Ruby — no mutate.sh involved. lib/mutate.sh stays untouched in this phase.

</canonical_refs>

<code_context>
## Existing Code Insights

### CONJURE_HOME Hotspot
- `cli/conjure` line 7 (approx): `CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"`
  Change to: `CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"`
  One character fix; everything else in cli/conjure already uses `$CONJURE_HOME` correctly.

### release.yml Structure
- Existing steps: checkout → verify VERSION matches tag → extract CHANGELOG → create release
- New step appends after "Create release": bump-homebrew-formula-action@v3
- Needs `contents: write` permission (already present) + new `HOMEBREW_TAP_GITHUB_TOKEN` secret reference

### Test Patterns
- BREW tests should go in `tests/run.sh` as a labeled block (BREW-01 through BREW-04)
- BREW-01 (brew install) cannot be automated in CI — document as manual in VALIDATION.md
- BREW-02 (CONJURE_HOME) CAN be unit-tested: set CONJURE_HOME=/tmp/fake, call cli/conjure version, verify it reads /tmp/fake/VERSION
- BREW-03 (no HEAD ref) CAN be checked: grep formula for 'branch' or 'HEAD' — must be absent
- BREW-04 (auto-bump) partially testable: check workflow YAML contains bump action reference

</code_context>

<specifics>
## Specific Ideas

- Formula wrapper uses Ruby heredoc in `def install` — standard Homebrew pattern; no shellcheck needed
- CONJURE_HOME env var already honored if set externally (after D-03 fix) — test by: `CONJURE_HOME=/tmp/x conjure version` reading `/tmp/x/VERSION`
- `Formula/conjure.rb` committed to this repo serves as the authoritative template; tap repo gets identical file
- `brew audit --formula Formula/conjure.rb` in CI would catch formula linting issues
- For BREW-04, the bump action can be pinned to `v3` by SHA for supply-chain safety

</specifics>

<deferred>
## Deferred Ideas

- `brew test conjure` beyond `--version` check — deferred; init requires a target dir which complicates test blocks
- macOS-only formula features (`on_macos { ... }`) — deferred; formula ships as cross-platform (macOS + Linux via brew on Linux)
- Pinning bump action to exact SHA — deferred; `@v3` is acceptable for Phase 13; SHA pinning is a Phase 15 hardening concern
- `brew bottle` binary bottle creation — deferred; source-only formula ships first
- Formula `depends_on "shellcheck"` — deferred; preflight already checks for shellcheck; not a runtime dep

</deferred>

---

*Phase: 13-homebrew-tap*
*Context gathered: 2026-05-26*
