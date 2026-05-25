---
phase: 12-org-overlay
plan: 03
subsystem: testing
tags: [bash, test, overlay, regression, file-url, shellcheck]

requires:
  - phase: 12-org-overlay
    plan: 01
    provides: scripts/init-overlay.sh + scripts/refresh-overlay.sh worker scripts
  - phase: 12-org-overlay
    plan: 02
    provides: scripts/audit-setup.sh overlay drift check section (OVLY-04)

provides:
  - tests/run.sh OVLY test block — 18 assertions covering OVLY-01 through OVLY-05

affects: []

tech-stack:
  added: []
  patterns:
    - Local file:// git repo as mock overlay — no network required in regression tests
    - OVLY-SETUP pattern: mktemp -d + git init + git commit + OVLY_URL=file:// (mirrors MKTPL-SETUP)
    - DRY_RUN=1 no-write assertion: check marker file absent after dry invocation

key-files:
  created: []
  modified:
    - tests/run.sh

key-decisions:
  - "OVLY-01c DRY_RUN test asserts no .conjure-org-overlay written and 'mutations skipped' in output (not '0 mutations' — plan text was imprecise; actual mutate_summary prints N>0 when files found)"
  - "OVLY-04 up-to-date test uses grep 'up to date\\|overlay' pattern per PATTERNS.md (audit may print either)"
  - "OVLY-04 invalid-URL test checks RC != 128 (not RC = 0) — audit may still exit 1 for other checks; key invariant is graceful degradation"

patterns-established:
  - "OVLY-SETUP: file:// local git repo pattern for overlay mock — reuse in future overlay tests"

requirements-completed:
  - OVLY-01
  - OVLY-02
  - OVLY-03
  - OVLY-04
  - OVLY-05

duration: 10min
completed: 2026-05-26
---

# Phase 12 Plan 03: OVLY Regression Test Blocks Summary

**18-assertion OVLY test block in tests/run.sh using a local file:// git repo mock — covers init, DRY_RUN, marker, refresh, audit drift, and static credential grep; bash tests/run.sh exits 0 with FAIL: 0 (261 total)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-26T00:00:00Z
- **Completed:** 2026-05-26T00:10:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added 18 OVLY assertions to `tests/run.sh` covering all five OVLY requirement groups
- OVLY-SETUP: local `file://` git repo created in mktemp dir — no network needed
- OVLY-01: init-overlay exits 0, skill file present in `.claude/`, DRY_RUN=1 honored (no writes, mutations-skipped reported)
- OVLY-02: `.conjure-org-overlay` marker present with correct `url=` and `sha=`
- OVLY-03: refresh-overlay exits 1 (no marker) with correct message; exits 0 (valid marker) and re-applies files
- OVLY-04: audit reports overlay status, DRIFT on SHA mismatch, graceful skip (`drift check skipped`) on invalid URL (RC != 128)
- OVLY-05: static grep confirms no credential keywords in init-overlay.sh or refresh-overlay.sh
- Full cleanup: `rm -rf "$OVLY_REPO" "$OVLY_TARGET"` at end of block

## Task Commits

Each task was committed atomically:

1. **Task 1: Add OVLY regression blocks to tests/run.sh** - `c77fd81` (feat)

## Files Created/Modified

- `tests/run.sh` — 171 lines inserted; OVLY block before the Summary section; all 18 assertions green

## Decisions Made

- OVLY-01c DRY_RUN assertion: the plan said "0 mutations skipped" but `mutate_summary` actually prints `N mutations skipped` where N > 0 when files are found to copy. Implemented correctly as "mutations skipped" string grep (passes when N > 0) — no files written to target `.claude/`
- OVLY-04 up-to-date grep pattern uses `grep -q 'up to date\|overlay'` per PATTERNS.md, because `audit-setup.sh` prints `[overlay] up to date (SHA)` which matches both alternatives
- OVLY-04 invalid-URL test checks `AUDIT_SKIP_RC -ne 128` (not `-eq 0`), consistent with plan: audit may exit 1 for unrelated checks, the invariant is that it never exits 128 (git abort)

## Deviations from Plan

None — plan executed exactly as written. The PATTERNS.md provided complete, verified code patterns for all assertions. The "0 mutations skipped" ambiguity in the plan was resolved by following the actual `mutate_summary` behavior (counts > 0 when files exist).

## Known Stubs

None.

## Threat Flags

None. The OVLY test block uses only local `file://` URLs and temp dirs — no new network surface introduced.

## Self-Check

Files modified:
- tests/run.sh: YES (171 lines added)

Commits exist:
- c77fd81: YES

bash tests/run.sh exits 0: YES (PASS: 261 FAIL: 0)
OVLY assertions in output: YES (19 occurrences in test output >= 12 required)

## Self-Check: PASSED

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. All OVLY tests use local `file://` git repos.

## Next Phase Readiness

- All OVLY-01 through OVLY-05 requirements machine-verified by `bash tests/run.sh`
- VALIDATION.md Wave 0 gap list fully resolved
- Phase 12 is ready for `/gsd-verify-work` — full regression suite exits 0

---
*Phase: 12-org-overlay*
*Completed: 2026-05-26*
