---
phase: 02-dry-run-enforcement-chokepoint
plan: "01"
subsystem: infra
tags: [bash, dry-run, mutation-chokepoint, posix, shell-library]

# Dependency graph
requires: []
provides:
  - "lib/mutate.sh: sourced bash library with mutate_mkdir, mutate_cp, mutate_write, mutate_summary"
  - "SAFE-02 chokepoint: single gate that suppresses all mutations when DRY_RUN=1"
affects:
  - 02-02  # init-project.sh retrofit (Wave 1a)
  - 02-03  # profiles retrofit (Wave 1b)
  - 02-04  # compliance retrofit (Wave 1c)
  - 02-05  # cli/conjure cmd_init wiring (Wave 2)
  - 02-06  # integration test (Wave 3)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mutation chokepoint: all filesystem writes (mkdir/cp/write) route through lib/mutate.sh functions"
    - "DRY_RUN env-var threading: inherited by child scripts via CONJURE_HOME=... DRY_RUN=... bash child.sh"
    - "Counter accumulation: CONJURE_DRY_MUTATION_COUNT incremented in current shell (not subshell) so count is never lost"
    - "printf over echo: mutate_write uses printf '%s\\n' \"$content\" for cross-platform portability"
    - "set -u safety: every variable access uses ${VAR:-default} throughout library"

key-files:
  created:
    - lib/mutate.sh
  modified: []

key-decisions:
  - "mutate_summary checks CONJURE_DRY_MUTATION_COUNT > 0 in addition to DRY_RUN=1 — handles both exported env var and per-command prefix usage patterns"
  - "mutate_cp auto-detects [ -d src ] and uses cp -r for directories, plain cp for files — callers use single uniform signature"
  - "No set -uo pipefail in library — follows project idiom that libraries do not set shell options; callers own their own option state"

patterns-established:
  - "source \"$CONJURE_HOME/lib/mutate.sh\" — all retrofitted scripts source via CONJURE_HOME (absolute; never relative paths)"
  - "mutate_summary at tail of each script before informational echo — prints count only if DRY_RUN=1 or count > 0"

requirements-completed: [SAFE-02]

# Metrics
duration: 8min
completed: 2026-05-24
---

# Phase 2 Plan 01: Create lib/mutate.sh — Mutation Chokepoint Library Summary

**POSIX bash 3.2+ sourced mutation library with mutate_mkdir/mutate_cp/mutate_write/mutate_summary implementing the SAFE-02 dry-run chokepoint — all 121 existing tests pass**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-24T20:00:00Z
- **Completed:** 2026-05-24T20:08:17Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `lib/` directory (new in v0.3.0) and `lib/mutate.sh` as the sole mutation abstraction
- Implemented all four functions per D-01/D-02/D-05: mutate_mkdir, mutate_cp, mutate_write, mutate_summary
- Library is safe to source under `set -uo pipefail` with no prior env vars set
- All acceptance criteria pass including syntax check, dry-run suppression, live mode creation, counter accumulation, and mutate_write --append
- 121 existing tests continue to pass (no regressions)

## Task Commits

1. **Task 1: Create lib/mutate.sh** - `48abdf2` (feat)

**Plan metadata:** (SUMMARY commit — see below)

## Files Created/Modified

- `lib/mutate.sh` — Sourced POSIX bash 3.2+ library implementing mutate_mkdir, mutate_cp, mutate_write, mutate_summary; DRY_RUN=1 suppresses all mutations and prints [dry-run] prefix; CONJURE_DRY_MUTATION_COUNT accumulates count; safe under set -uo pipefail

## Decisions Made

1. **mutate_summary triggers on count > 0 as well as DRY_RUN=1** — The acceptance criterion uses `DRY_RUN=1 mutate_mkdir /tmp/x; mutate_summary` where `DRY_RUN=1` is a per-command prefix (temporary env for shell function, not persistent). After `mutate_mkdir` returns, `DRY_RUN` is unset in the calling shell. Checking `CONJURE_DRY_MUTATION_COUNT > 0` allows `mutate_summary` to print correctly in both usage patterns (per-command prefix AND exported env var).

2. **mutate_cp auto-detects directory vs file** — Uses `[ -d "$1" ]` to decide between `cp -r` and plain `cp`, giving callers a single uniform signature without needing separate functions. This covers all 12 write sites in init-project.sh including loop-based copies.

3. **No set -uo pipefail in library** — Followed PATTERNS.md idiom: "libraries do not set shell options." Library is sourced into callers that already set their own options.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] mutate_summary counter-visibility fix via count check**
- **Found during:** Task 1 (acceptance criteria verification)
- **Issue:** Acceptance criterion `bash -c 'source lib/mutate.sh; DRY_RUN=1 mutate_mkdir /tmp/x; mutate_summary'` fails because `DRY_RUN=1` as a per-command prefix for a shell function is only visible during the function call, not after. After `mutate_mkdir` returns, `DRY_RUN` is unset in the outer shell, so `mutate_summary` (checking only `DRY_RUN=1`) would print nothing.
- **Fix:** Added `|| [ "${CONJURE_DRY_MUTATION_COUNT:-0}" -gt 0 ]` condition to `mutate_summary`. If any mutations were suppressed (count > 0), the summary prints. In live mode, count stays 0 so summary is silent. Real CLI usage (exported env var) continues to work unchanged.
- **Files modified:** lib/mutate.sh
- **Verification:** `bash -c 'source lib/mutate.sh; DRY_RUN=1 mutate_mkdir /tmp/x; mutate_summary'` now outputs `[dry-run] 1 mutations skipped — run without --dry-run to apply`; live mode (`DRY_RUN=0`) produces no output
- **Committed in:** 48abdf2

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in acceptance test behavior)
**Impact on plan:** Auto-fix essential for acceptance criteria compliance. The fix is strictly correct: real CLI usage (exported DRY_RUN) continues to work identically; per-command prefix usage now also works.

## Issues Encountered

None — plan executed smoothly. The counter-visibility issue was caught immediately during acceptance verification and fixed inline.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `lib/mutate.sh` is complete and verified — Wave 1 work (Plans 02-02, 02-03, 02-04) can proceed in parallel
- All retrofitted scripts must use `source "$CONJURE_HOME/lib/mutate.sh"` (absolute path via CONJURE_HOME)
- All scripts must call `mutate_summary` at their tail before informational output
- Wave 2 (cli/conjure wiring) and Wave 3 (integration tests) depend on Wave 1 completion

---
*Phase: 02-dry-run-enforcement-chokepoint*
*Completed: 2026-05-24*
