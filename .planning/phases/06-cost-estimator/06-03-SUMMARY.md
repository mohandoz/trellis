---
phase: 06-cost-estimator
plan: "03"
subsystem: cost-estimator
tags:
  - cost-estimator
  - testing
  - regression-suite
dependency_graph:
  requires:
    - lib/prices.json (Plan 01)
    - scripts/audit-setup.sh cost section (Plan 02)
  provides:
    - tests/run.sh cost estimator test section (COST-01, COST-02, COST-03 automated assertions)
  affects:
    - tests/run.sh (8 new assertions, 177 → 185 passing)
tech_stack:
  added: []
  patterns:
    - CONJURE_COST=1 env var guard invocation pattern for cost section testing
    - sandbox_setup + trap EXIT isolation pattern (mirrored from fixture audit section)
    - grep -qE "Estimate: \\$[0-9]+\\.[0-9]{2} ±20%" pattern for float label validation
    - grep -v '^#' | grep -cE for non-comment network call detection
key_files:
  created: []
  modified:
    - tests/run.sh (cost estimator test section: 70 lines appended before final summary block)
decisions:
  - "Use python-fastapi as the cost test fixture (known green fixture, minimal setup)"
  - "Capture COST_OUT before assertions so all tests run against same invocation"
  - "NO_NET_COUNT uses || true so grep returning 1 (no matches) does not fail under set -e"
metrics:
  duration_minutes: 12
  tasks_completed: 1
  tasks_total: 1
  files_created: 0
  files_modified: 1
  completed_at: "2026-05-25T04:00:00Z"
requirements_satisfied:
  - COST-01
  - COST-02
  - COST-03
---

# Phase 06 Plan 03: Regression Suite — Summary

**One-liner:** Eight grep-based assertions in tests/run.sh encoding COST-01/02/03 requirements — cost header, ±20% label format, pricing date, model name, no-network guarantee, and --exact fallback advisory — closing the Nyquist gap for the cost estimator.

## What Was Built

### Task 1: Cost estimator test section in tests/run.sh

Added the "Cost estimator tests (COST-01, COST-02, COST-03)" section immediately before the final summary block in `tests/run.sh`. The section uses the `python-fastapi` fixture via `sandbox_setup` for isolation and captures `CONJURE_COST=1 bash scripts/audit-setup.sh` output to a variable for all assertions.

**COST-01 assertions (2):**
- `grep -q "── Cost Estimate ──"` — cost section header present
- `[ "$COST_RC" -le 2 ]` — cost section does not crash

**COST-02 assertions (3):**
- `grep -qE "Estimate: \$[0-9]+\.[0-9]{2} ±20%"` — label has ±20% band
- `grep -q "prices:"` — label contains pricing date
- `grep -q "claude-sonnet-4-6"` — model name in output

**COST-03 assertions (3):**
- `grep -v '^#' scripts/audit-setup.sh | grep -cE "curl|fetch|http[s]?:"` count == 0 — no network calls in default path
- `CONJURE_EXACT=1 ANTHROPIC_API_KEY="" bash scripts/audit-setup.sh` output contains "ANTHROPIC_API_KEY not set" — fallback advisory present
- `[ "$EXACT_RC" -le 2 ]` — --exact fallback exits cleanly

**JSON validity loop (pre-existing, Plan 01 deviation):**
The `find templates .claude-plugin lib -name '*.json'` scope already includes `lib/` from Plan 01. `lib/prices.json` passes `jq empty` validation as `✓ json valid: lib/prices.json`.

**Final suite result:** PASS: 185, FAIL: 0 (was PASS: 177, FAIL: 0 before this plan)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 424a01d | feat(06-03): extend tests/run.sh with cost estimator test section (COST-01, COST-02, COST-03) |

## Verification Results

All acceptance criteria from the plan pass:

1. `bash tests/run.sh` exits 0 — PASS
2. `grep -c "▸ Cost estimator tests"` == 1 — PASS
3. `grep -c "✓ cost section header present"` == 1 — PASS
4. `grep -c "✓ cost label has ±20% band"` == 1 — PASS
5. `grep -c "✓ cost label contains pricing date"` == 1 — PASS
6. `grep -c "✓ cost output names the model"` == 1 — PASS
7. `grep -c "✓ audit-setup.sh has no network calls"` == 1 — PASS
8. `grep -c "✓ --exact fallback advisory present"` == 1 — PASS
9. `grep -c "✓ json valid: lib/prices.json"` == 1 — PASS
10. `grep -c "✗"` == 0 — PASS

## Deviations from Plan

### Pre-existing State Note

The plan's EDIT 1 (extending the JSON find scope to include `lib/`) was already applied in Plan 01 as a Rule 2 auto-fix deviation (recorded in 06-01-SUMMARY.md). The worktree started behind main and was brought up to date via `git merge main` before task execution. The JSON validity loop was already correct in the merged state.

No other deviations. Plan executed as specified after merge.

## Known Stubs

None. All 8 assertions are complete, active, and passing. No placeholder or hardcoded values in the test section.

## Threat Flags

No new threat surface. The test section:
- Sets `ANTHROPIC_API_KEY=""` explicitly for the fallback test (T-06-31 — mitigated as designed)
- Captures output to a local variable from a local script on a local fixture (T-06-32 — accepted)
- Uses `sandbox_setup` + `trap EXIT` for cleanup (T-06-33 — accepted)
- Makes no network calls (confirmed by COST-03 test itself)

## Self-Check: PASSED

- `tests/run.sh` — FOUND, modified (+70 lines)
- Commit 424a01d — FOUND (`git log --oneline -1` confirms)
- `bash tests/run.sh` — PASS: 185, FAIL: 0
- `grep -c "▸ Cost estimator tests" /tmp/conjure-test-out.txt` — 1
- `grep -c "✗" /tmp/conjure-test-out.txt` — 0
- `grep -c "✓ json valid: lib/prices.json" /tmp/conjure-test-out.txt` — 1
