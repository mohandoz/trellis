---
phase: 22-conjure-adopt-cli-core-rollback
plan: 01
subsystem: testing
tags: [bash, tests, fixtures, adopt, rollback, sigkill, jq, graceful-red, nyquist]

# Dependency graph
requires:
  - phase: 21-foundation-libs-inventory
    provides: "lib/snapshot.sh, lib/inventory.sh, lib/log.sh, lib/caps.sh, mutate_archive, adopt-manifest.schema.json, brownfield-simple fixture, tests/run.sh Phase 21 block + tests/lib/sandbox.sh"
provides:
  - "▸ Phase 22 graceful-red test block in tests/run.sh (9 sections) covering all 5 ROADMAP criteria + SAFE-04/SAFE-07 + D-08 + Pitfall 3"
  - "Synthetic restructure_steps[] manifest fixture (tests/fixtures/_adopt-restructure-steps/adopt-manifest.json) — 1 write + 1 archive op (D-08)"
  - "git-init dirty-tree harness (criterion 3) and non-TTY SIGKILL recovery harness (criterion 5)"
  - "A concrete red→green executable contract Wave 1/Wave 2 verify against (bash tests/run.sh 2>&1 | grep -E 'Phase 22|✗')"
affects: [22-02 (cmd_adopt + scripts/adopt.sh pipeline), 22-03 (apply-step/update-manifest + recovery), 24 (Argus integration + zero-diff)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Graceful-red Wave 0: assertions target real behavior but guard every invocation behind [ -f scripts/adopt.sh ] so the suite reports red without crashing while production code is absent"
    - "_-prefixed fixture dirs are excluded from the generic tests/fixtures/[^_]*/ audit + golden-EXPECT loops (data fixtures, not harness fixtures)"
    - "Bounded poll for async readiness (for _i in $(seq 1 50); ... sleep 0.1) instead of a blind long sleep, with kill -0 early-exit"

key-files:
  created:
    - tests/fixtures/_adopt-restructure-steps/adopt-manifest.json
  modified:
    - tests/run.sh

key-decisions:
  - "Renamed the synthetic fixture to _adopt-restructure-steps so the generic fixture-audit loop (tests/fixtures/[^_]*/) skips it — a data-input fixture has no CLAUDE.md and must not be run through audit-setup.sh"
  - "State assertion supports both .conjure-adopt-state forms (single file or directory + state.json) since the schema is the Wave 1 planner's discretion (CONTEXT.md)"
  - "SIGKILL recovery test asserts the reliably-automatable non-TTY exit-2 + last-completed form; the interactive [r]/[c]/[s] prompt is deferred to VALIDATION.md manual-verification"

patterns-established:
  - "Graceful-red guard: P22_ADOPT_OK gate + 'Wave 1 must create scripts/adopt.sh first' fail message per section"
  - "p22_adopt / p22_sha local helpers (env-var contract invoker + cross-platform sha256) reused across sections — not assertion functions"

requirements-completed: [ADOPT-01, ADOPT-02, ADOPT-04, ADOPT-05, ADOPT-06, SAFE-01, SAFE-02, SAFE-04, SAFE-05, SAFE-06, SAFE-07]

# Metrics
duration: 18min
completed: 2026-05-28
---

# Phase 22 Plan 01: Phase 22 Test Infrastructure (Wave 0, test-first) Summary

**Graceful-red `▸ Phase 22` test block (9 sections) in tests/run.sh plus a synthetic 2-op restructure_steps[] manifest fixture — the executable red→green contract that gates every later Phase 22 verification before scripts/adopt.sh exists.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-05-28T23:15Z (approx)
- **Completed:** 2026-05-28
- **Tasks:** 3
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- Appended a `▸ Phase 22 — conjure adopt` block (9 sub-sections) to `tests/run.sh` before the gh-stub cleanup, mirroring the Phase 21 block style (`t`/`pass`/`fail` helpers, mktemp sandboxes, set/`trap - EXIT` reset discipline). Covers all five ROADMAP success criteria + SAFE-04/SAFE-07 + D-05/D-06/D-08 + Pitfall 3.
- Every adopt invocation is guarded behind `[ -f scripts/adopt.sh ]`, so the suite degrades gracefully: the 9 Phase 22 assertions report red ("Wave 1 must create scripts/adopt.sh first") while the Phase 21 + v0.5.0 blocks stay green (PASS: 359 preserved), and the runner completes without crashing.
- Hand-authored a schema-valid synthetic `restructure_steps[]` manifest fixture with exactly one `write` op (staging-path src per D-07) and one `archive` op (D-08) — the seam the Wave 2 `--apply-step`/`--update-manifest` executor is tested against.
- Built the two net-new harnesses from PATTERNS.md "No Analog Found": a `git init`-ed dirty-tree sandbox (criterion 3) and a background-launch + bounded-poll + `kill -9` non-TTY SIGKILL recovery harness asserting `exit 2` + `last completed:` + the three recovery flags (criterion 5).

## Task Commits

Each task was committed atomically:

1. **Task 1: Synthetic restructure_steps[] manifest fixture (D-08)** — `a6694fd` (test)
2. **Task 2: Phase 22 test block — pipeline + safety assertions** — `1de57ac` (test)
3. **Task 3: Dirty-tree + SIGKILL recovery + apply-step harnesses** — `6c088fa` (test)

**Plan metadata:** _(this docs commit)_

## Files Created/Modified

- `tests/fixtures/_adopt-restructure-steps/adopt-manifest.json` — Synthetic, schema-valid manifest with a populated `restructure_steps[]` (step-1 `write` referencing `.conjure-adopt-state/staging/CLAUDE.md`, step-2 `archive` of `docs/OLD.md`); seeds the Wave 2 op-executor tests. `_`-prefixed so the generic fixture-audit loop skips it.
- `tests/run.sh` — Added the `▸ Phase 22` graceful-red block (9 sections): dry-run zero-writes (ADOPT-02/D-11), live scaffold+idempotency+report (ADOPT-01/04/05/06/SAFE-01), dirty-tree exit-2/`--force`-WARN (ADOPT-03/SAFE-06), rollback sha256 + zero-diff (SAFE-02/D-03), state+log (SAFE-04/SAFE-07), git-init dirty-tree harness, SIGKILL recovery (SAFE-05), `--apply-step`/`--update-manifest` (D-05/D-06/D-08), and the Pitfall-3 snapshot self-copy regression.

## Decisions Made

- **`_`-prefix the synthetic fixture** so the generic `tests/fixtures/[^_]*/` audit loop and golden-EXPECT loop both skip it — consistent with how `_broken` is excluded. A data-input fixture has no `CLAUDE.md` and is not meant to pass `audit-setup.sh`.
- **State assertion tolerates both `.conjure-adopt-state` forms** (a single JSON file, or a directory containing `state.json` + `staging/`) because the exact schema/layout is the Wave 1 planner's discretion per CONTEXT.md; D-07's literal `staging/<file>` path leans directory-form.
- **SIGKILL test asserts the non-TTY `exit 2` + `last completed:` form** (the reliably-automatable signal); the interactive `[r]/[c]/[s]` prompt is left to VALIDATION.md's manual-verification table.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Synthetic fixture broke the generic fixture-audit loop**
- **Found during:** Task 2 (running the full suite to verify graceful-red)
- **Issue:** The plan placed the fixture at `tests/fixtures/adopt-restructure-steps/`. The pre-existing "Fixture audits — sandboxed" loop (`tests/run.sh` line 326) iterates `tests/fixtures/[^_]*/` and runs `audit-setup.sh` against each. The new manifest-only fixture (no `CLAUDE.md`) was swept in and produced two real failures (`fixture audit non-green (rc=2): adopt-restructure-steps`, `CLAUDE.md missing`), polluting the suite beyond the intended graceful-red Phase 22 reds.
- **Fix:** `git mv` the fixture to `tests/fixtures/_adopt-restructure-steps/`. The `_` prefix excludes it from the generic-audit + golden-EXPECT loops (same convention `_broken` uses). Updated the Task 3 `--apply-step` seeding path accordingly.
- **Files modified:** `tests/fixtures/_adopt-restructure-steps/adopt-manifest.json` (renamed), `tests/run.sh`
- **Verification:** Full suite back to `PASS: 359 FAIL: 9` — the 9 fails are exactly the graceful-red Phase 22 sections; the two spurious fixture-audit fails are gone.
- **Committed in:** `1de57ac` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix preserves the Phase 21 baseline (359 green) and keeps the suite's only reds as the intended Wave 0 graceful-red signal. No scope creep; the fixture content is unchanged, only its directory name.

## Issues Encountered

- An attempt to measure the "before" baseline by copying `tests/run.sh` to `/tmp` and running it there produced a misleading mass-failure (the copied script's `dirname`-derived `CONJURE_HOME` resolved to `/tmp/..`, breaking all path lookups). Resolved by validating in-place instead: the real in-tree run cleanly shows `PASS: 359 FAIL: 9` (graceful-red only).

## Known Stubs

None. This plan creates only test assertions and a test fixture; there is no production data-flow to stub. The 9 graceful-red Phase 22 assertions are intentional pending/red signals (not stubs) that turn green when Wave 1/Wave 2 land `scripts/adopt.sh` + `cmd_adopt`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Wave 1 (`22-02`) can now build `cmd_adopt` + `scripts/adopt.sh` (preconditions → snapshot → inventory dry-run temp manifest → scaffold → audit → report + `.conjure-adopt-state` + INT/TERM trap + self-copy guard) against a concrete red→green target: `bash tests/run.sh 2>&1 | grep -E "Phase 22|✗"`.
- Wave 2 (`22-03`) `--apply-step`/`--update-manifest` executor verifies against `tests/fixtures/_adopt-restructure-steps/adopt-manifest.json` and the non-TTY recovery harness.
- Note for the Wave 1 planner: the state assertion accepts either a `.conjure-adopt-state` file or a `.conjure-adopt-state/state.json` directory layout; `.mutated[].before` (sha256) and a `created[]` array are required by the SAFE-04 + rollback assertions.
- Note for the Phase 24 (Argus) test author: per D-03 the zero-diff comparison excludes `.conjure-adopt-backups/`, `.conjure-archive-*`, `RESTRUCTURE-LOG.md`, `adopt-manifest.json`, and `.conjure-adopt-state` — the rollback section here uses exactly that exclude set.

## Self-Check: PASSED

- FOUND: `tests/fixtures/_adopt-restructure-steps/adopt-manifest.json`
- FOUND: `tests/run.sh` Phase 22 block (`▸ Phase 22`)
- FOUND: `.planning/phases/22-conjure-adopt-cli-core-rollback/22-01-SUMMARY.md`
- FOUND commits: `a6694fd`, `1de57ac`, `6c088fa`

---
*Phase: 22-conjure-adopt-cli-core-rollback*
*Completed: 2026-05-28*
