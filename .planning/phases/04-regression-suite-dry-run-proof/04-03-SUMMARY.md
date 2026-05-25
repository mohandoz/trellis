---
phase: 04-regression-suite-dry-run-proof
plan: "03"
subsystem: tests
tags: [testing, dry-run, failure-modes, regression, TEST-05, TEST-07]
dependency_graph:
  requires: [04-01]
  provides: [dry-run-byte-identical-snapshot, failure-mode-reproductions]
  affects: [tests/run.sh]
tech_stack:
  added: []
  patterns: [mktemp-cp-diff-comparison, synthetic-fixture-pattern, conjure-update-version-check]
key_files:
  created: []
  modified:
    - tests/run.sh
decisions:
  - "FM-1 uses 205 filler lines (206 total) to exceed the actual audit-setup.sh HARD CAP threshold of >200 lines — plan spec said >100 but the code uses 200 as the hard cap boundary"
  - "Dry-run snapshot section uses plain mktemp -d (not sandbox_setup) to avoid HOME/PATH clobbering that would contaminate diff -r comparison"
  - "Each dry-run loop iteration cleans up both DRY_ORIG and DRY_SNAP explicitly — belt-and-suspenders regardless of EXIT trap state"
  - "FM-2 uses grep -qE directly on the hook file — audit-setup.sh does not check hook exit codes (Finding F-01)"
  - "FM-3 version file at .claude/.conjure-version (not root level) — conjure update reads from inside .claude/"
metrics:
  duration: "~4 min"
  completed: "2026-05-25"
  tasks_completed: 2
  files_created: 0
  files_modified: 1
---

# Phase 4 Plan 03: Dry-Run Snapshot and Failure-Mode Reproductions Summary

**One-liner:** Dry-run byte-identical snapshot (TEST-05) and failure-mode reproductions (TEST-07) sections added to tests/run.sh — 12 new pass lines proving all 9 profiles are dry-run safe and three documented failure modes are CI-detectable.

## What Was Built

### Task 1: Dry-run byte-identical snapshot section (commit: 86d8ba2)

Inserted the `▸ Dry-run byte-identical snapshot (TEST-05)` section into `tests/run.sh` immediately after the Golden-file EXPECT loop (plan 04-01) and before the `# Summary` block. The section iterates all 9 green fixtures via the `[^_]*/` glob, copies each to two fresh `mktemp -d` directories (DRY_ORIG and DRY_SNAP), runs `conjure init --dry-run $DRY_SNAP`, then asserts `diff -r $DRY_SNAP $DRY_ORIG` exits 0. Uses plain `mktemp -d` (no `sandbox_setup`) to avoid HOME/PATH clobbering and EXIT trap conflicts. Explicit `rm -rf "$DRY_ORIG" "$DRY_SNAP"` per iteration. Result: 9 new pass lines, `PASS: 172  FAIL: 0`.

### Task 2: Failure-mode reproductions section (commit: 217a457)

Inserted the `▸ Failure-mode reproductions (TEST-07)` section immediately after the dry-run snapshot section and before the `# Summary` block. Three self-contained synthetic mini-fixture blocks:

- **FM-1 (size cap):** Creates a CLAUDE.md with 206 lines (1 header + 205 filler), runs `audit-setup.sh`, asserts `HARD CAP exceeded` in output.
- **FM-2 (hook exit 1):** Creates `.claude/hooks/bad-gate.sh` with `exit 1`, asserts `grep -qE '^exit 1$'` finds it directly (audit-setup.sh does not check hook exit codes).
- **FM-3 (version mismatch):** Creates `.claude/.conjure-version` with `0.1.0`, runs `cli/conjure update`, asserts output contains "pinned to" AND does NOT contain "Up to date".

Result: 3 new pass lines, full suite `PASS: 175  FAIL: 0`.

## Verification Results

All 7 success criteria from the plan met:

1. `grep -q 'Dry-run byte-identical snapshot (TEST-05)' tests/run.sh` → exit 0
2. `grep -q 'Failure-mode reproductions (TEST-07)' tests/run.sh` → exit 0
3. `bash tests/run.sh 2>&1 | grep -c 'dry-run snapshot identical'` → 9
4. `bash tests/run.sh 2>&1 | grep 'FM: size cap detected by audit'` → 1 line
5. `bash tests/run.sh 2>&1 | grep 'FM: hook exit 1 detectable via grep'` → 1 line
6. `bash tests/run.sh 2>&1 | grep 'FM: version mismatch detected by conjure update'` → 1 line
7. `bash tests/run.sh` exits 0 with `FAIL: 0`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FM-1 filler line count corrected from 105 to 205**
- **Found during:** Task 2 execution (FM-1 test failed — "size cap NOT detected")
- **Issue:** The plan specified `seq 1 105` to create 106 lines (1 header + 105 filler), stating this is ">100". However, `scripts/audit-setup.sh` uses 200 as the HARD CAP threshold — not 100. Lines 26-28 of audit-setup.sh: ≤100 = PASS, 101-200 = WARN, >200 = ERROR ("HARD CAP exceeded — trim"). 106 lines produces a warning, not the HARD CAP exceeded error.
- **Fix:** Changed `seq 1 105` to `seq 1 205` — produces 206 lines (1 header + 205 filler) which exceeds the actual 200-line HARD CAP threshold.
- **Files modified:** `tests/run.sh` (FM-1 block only)
- **Commit:** 217a457 (included in Task 2 commit)

## Known Stubs

None — all assertions are wired to live tool invocations (audit-setup.sh, grep, cli/conjure update). No placeholder data.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. New test sections use `mktemp -d` (mode 700) for synthetic fixtures, which are explicitly cleaned up after each block.

## Self-Check

- [x] tests/run.sh contains `▸ Dry-run byte-identical snapshot (TEST-05)` section
- [x] tests/run.sh contains `▸ Failure-mode reproductions (TEST-07)` section
- [x] Commit 86d8ba2 exists (Task 1)
- [x] Commit 217a457 exists (Task 2)
- [x] Full suite: `PASS: 175  FAIL: 0`
- [x] 9 dry-run snapshot identical passes
- [x] 3 FM passes (size cap, hook exit 1, version mismatch)
- [x] No FM:.*NOT output

## Self-Check: PASSED
