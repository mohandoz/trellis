---
phase: 23-restructure-skill-safety-gates
plan: 01
subsystem: testing
tags: [bash, tests, fixtures, graceful-red, restructure, safety-gates, nyquist]

# Dependency graph
requires:
  - phase: 22-conjure-adopt-cli
    provides: "scripts/adopt.sh op-executor seam (--apply-step / --update-manifest), _adopt-restructure-steps manifest fixture, the Phase 22 Wave 0 graceful-red idiom this block mirrors"
provides:
  - "Phase 23 graceful-red test block in tests/run.sh gating every Wave 1/2 deliverable"
  - "Synthetic gate fixtures under tests/fixtures/_restructure-gates/ (8 files)"
  - "Concrete red→green signal for the 4 gate helpers, SKILL.md scaffold, approval driver, group-by, archive-last, non-TTY exit-2"
affects: [23-02-gate-helpers, 23-03-skill-scaffold, restructure-skill, verify-invariants, audit-staged, decision-scan, extract-invariants]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "P23_RESTR_OK / P23_GATES_OK presence guards mirror P22_ADOPT_OK — every section reports graceful RED until Wave 1/2 ships the code"
    - "Leading-underscore fixture dir (_restructure-gates) to dodge the tests/fixtures/[^_]*/ audit + golden loops"
    - "Canonical-token INVARIANTS.txt + normalized-substring contract proven against case/whitespace-mangled fixtures"

key-files:
  created:
    - "tests/fixtures/_restructure-gates/INVARIANTS.txt"
    - "tests/fixtures/_restructure-gates/with-invariant.md"
    - "tests/fixtures/_restructure-gates/missing-invariant.md"
    - "tests/fixtures/_restructure-gates/reflowed-invariant.md"
    - "tests/fixtures/_restructure-gates/with-import.md"
    - "tests/fixtures/_restructure-gates/oversized.md"
    - "tests/fixtures/_restructure-gates/decision-doc.md"
    - "tests/fixtures/_restructure-gates/clean-doc.md"
  modified:
    - "tests/run.sh"

key-decisions:
  - "Reworded the extract-invariants seed CLAUDE.md so it does not contain the literal 'exit 1' substring — keeps the convention gate `grep -c 'exit 1'` at the 15-line baseline while still carrying the 'exit 2' invariant signal the test asserts on"
  - "INVARIANTS.txt holds 5 canonical tokens (exit 2, @import, ≤100, mutate.sh, do not delete), not full sentences (O-2)"
  - "approval driver path asserted as gates/approve.sh — the Wave-2 deliverable name the non-TTY exit-2 and bulk-summary tests target"

patterns-established:
  - "Pattern 1: graceful-red presence guards (P23_RESTR_OK/P23_GATES_OK) so Wave 0 asserts exist and report a clear 'Wave N must create ...' fail without crashing the suite"
  - "Pattern 2: group-by asserts read files[] per-class buckets (core=1, reference-doc=1, unknown=0) and keep .summary.unknown=1 distinct — no conflation of the two"

requirements-completed: [RESTR-01, RESTR-02, RESTR-03, RESTR-04, RESTR-05, RESTR-06]

# Metrics
duration: 14min
completed: 2026-05-29
---

# Phase 23 Plan 01: Restructure Gate Test-First Foundation Summary

**Graceful-red `▸ Phase 23 — restructure gate helpers` block in tests/run.sh plus 8 canonical-token gate fixtures, locking the Nyquist contract so every Wave 1/2 deliverable verifies against a red→green signal that already exists.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-05-29 (Phase 23 execution session)
- **Completed:** 2026-05-29
- **Tasks:** 2
- **Files modified:** 1 modified, 8 created

## Accomplishments
- New Phase 23 test section emits its header exactly once, reports graceful RED for all 4 gate helpers + SKILL.md scaffold + approval driver via "Wave N must create ..." messages, and never crashes the suite (mirrors the Phase 22 Wave 0 precedent exactly).
- 8 synthetic gate fixtures under `tests/fixtures/_restructure-gates/` (leading underscore excludes them from the generic audit/golden loops at run.sh:326/368/390).
- Normalized-substring invariant contract proven: every canonical token is a substring of normalized `with-invariant.md` and `reflowed-invariant.md` (case + whitespace mangled), while `missing-invariant.md` drops `exit 2` and `do not delete`.
- The un-guarded apply-step routing (RESTR-02) and group-by (RESTR-01) assertions pass immediately against the shipped Phase 22 seam — +5 new green assertions (401 → 406 PASS).

## Task Commits

Each task was committed atomically:

1. **Task 1: Phase 23 graceful-red test block + presence guards in tests/run.sh** - `5975d52` (test)
2. **Task 2: Synthetic gate fixtures under tests/fixtures/_restructure-gates/** - `2b1ba16` (test)

## Files Created/Modified
- `tests/run.sh` - Added the `▸ Phase 23 — restructure gate helpers` block (315 lines) before the Summary: presence guards (P23_RESTR_OK/P23_GATES_OK), guarded sections for verify-invariants / audit-staged / decision-scan / extract-invariants / scaffold criterion 1 / apply-step routing / group-by / archive-last / non-TTY exit-2 approval / bulk RESTRUCTURE summary line.
- `tests/fixtures/_restructure-gates/INVARIANTS.txt` - 5 canonical tokens (exit 2, @import, ≤100, mutate.sh, do not delete).
- `tests/fixtures/_restructure-gates/with-invariant.md` - proposed CLAUDE.md containing every token → verify-invariants rc 0.
- `tests/fixtures/_restructure-gates/missing-invariant.md` - drops 2 tokens → verify-invariants rc 2 + missing list.
- `tests/fixtures/_restructure-gates/reflowed-invariant.md` - case/whitespace-mangled but content-complete → rc 0 (D-07 normalized match).
- `tests/fixtures/_restructure-gates/with-import.md` - first non-blank line `@import ./extra.md` → audit-staged rc 2 (^@ trigger).
- `tests/fixtures/_restructure-gates/oversized.md` - 215 lines (>200, >CLAUDE_MD_CAP=100) → audit-staged rc 2 cap-breach.
- `tests/fixtures/_restructure-gates/decision-doc.md` - matches the 5-term scan → decision-scan "individual".
- `tests/fixtures/_restructure-gates/clean-doc.md` - matches none + @import-free ≤100 lines → decision-scan "bulk" AND audit-staged rc 0.

## Decisions Made
- **`exit 1` literal in seed content:** The first draft of the extract-invariants seed CLAUDE.md contained the phrase "never exit 1", which the project convention gate (`grep -v '^#' tests/run.sh | grep -c 'exit 1'`) counted, pushing it from the 15-line baseline to 16. Reworded to "exit 2 to block; never use a hard error code" — preserves the `exit 2` signal the extract test asserts on while keeping the gate at baseline 15.
- **Approval driver path:** Asserted the Wave-2 approval entry as `gates/approve.sh`. The non-TTY exit-2 and bulk-summary sub-sections guard on its presence and report graceful RED until Wave 2 ships it.
- **Group-by source field:** Asserted from `files[]` per-class selection (core=1, reference-doc=1, unknown=0) and kept `.summary.unknown=1` as a separate assertion — avoids the conflation trap the plan flagged (the fixture's files[] has 2 entries; the summary carries the aggregate).

## Deviations from Plan

None - plan executed exactly as written. (The `exit 1` reword and the `gates/approve.sh` path choice were both anticipated by the plan: the plan mandates zero new `exit 1` and leaves the Wave-2 driver path to assert "whatever the Wave-1/2 contract specifies, written as a pending-but-present assertion".)

## Issues Encountered
- The synthetic seed string "never exit 1" briefly tripped the `exit 1` convention count (15 → 16). Resolved by rewording the seed content before committing Task 1; final count is 15 (baseline). No other issues.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Wave 1 (23-02) can now create the 4 gate helpers (`gates/verify-invariants.sh`, `audit-staged.sh`, `decision-scan.sh`, `extract-invariants.sh`) and watch the 4 corresponding "Wave 1 must create ..." reds flip green.
- Wave 2 (23-03) can create the `restructure` SKILL.md + the init-project.sh scaffold edit + `gates/approve.sh`, flipping the remaining 4 reds (scaffold criterion 1, archive-last, non-TTY exit-2, bulk summary).
- No blockers. The full suite is at 406 PASS / 8 FAIL where all 8 fails are intentional graceful-red guards; zero pre-Phase-23 regression.

## TDD Gate Compliance
This plan is test-first (Wave 0) at the plan level rather than per-task `tdd="true"`. The RED gate is satisfied: both commits are `test(...)` commits that add failing/guarded-red assertions before the production helpers exist (the canonical Wave 0 RED). GREEN commits land in Waves 1-2 (the gate helpers and SKILL.md). This matches the established Phase 22 Wave 0 precedent.

## Self-Check: PASSED

All 8 created fixtures + the SUMMARY exist on disk; both task commits (`5975d52`, `2b1ba16`) are present in git history. tests/run.sh parses clean under `bash -n`, emits the `▸ Phase 23` header once, reports the graceful-red "Wave N must create ..." guards, holds the `exit 1` convention count at the 15-line baseline, and introduces zero pre-Phase-23 regression (401 baseline assertions stay green).

---
*Phase: 23-restructure-skill-safety-gates*
*Completed: 2026-05-29*
