---
phase: 02-dry-run-enforcement-chokepoint
plan: "05"
subsystem: cli
tags: [bash, dry-run, mutation-chokepoint, posix, cli, env-var-threading]

# Dependency graph
requires:
  - "02-01: lib/mutate.sh — mutation chokepoint library"
  - "02-02: scripts/init-project.sh — retrofitted with mutate_* calls"
  - "02-03: profiles/*/apply.sh — retrofitted with mutate_* calls"
  - "02-04: compliance/*/apply.sh — retrofitted with mutate_* calls"
provides:
  - "cli/conjure cmd_init(): DRY_RUN threaded to init-project.sh via env prefix"
  - "cli/conjure cmd_init(): DRY_RUN threaded to profiles/*/apply.sh via env prefix; positional $dryrun arg removed"
  - "cli/conjure cmd_init(): version stamp write routed through mutate_write + mutate_summary"
  - "SAFE-01 closed end-to-end: conjure init --dry-run produces [dry-run] lines and leaves target tree unchanged"
affects:
  - 02-06  # integration test (Wave 3) — verifies end-to-end dry-run via tests/run.sh

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DRY_RUN env-var set in parent shell (DRY_RUN=dryrun) before sourcing lib/mutate.sh — enables chokepoint to read flag within same process"
    - "Env-prefix threading for subprocess calls: CONJURE_HOME=... DRY_RUN=... bash script — same pattern as cmd_migrate at line 107"
    - "Positional $dryrun arg removed from profile apply.sh: env var replaces positional arg uniformly across all scripts"

key-files:
  created: []
  modified:
    - cli/conjure

key-decisions:
  - "Set DRY_RUN=dryrun in current shell after arg parsing — lib/mutate.sh reads DRY_RUN at call time; setting it before source and mutate_write calls enables the chokepoint to work within cmd_init() without subprocess overhead"
  - "Source lib/mutate.sh after arg parsing (not before) so DRY_RUN is already known when source runs and counter initializes correctly"

requirements-completed: [SAFE-01, SAFE-02]

# Metrics
duration: 8min
completed: 2026-05-24
---

# Phase 2 Plan 05: Wire DRY_RUN Threading in cli/conjure cmd_init() Summary

**DRY_RUN env-var threaded to all cmd_init() subprocess calls via env prefix; version stamp routed through mutate_write; conjure init --dry-run now leaves target tree byte-identical to before**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-24
- **Completed:** 2026-05-24
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added `CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun"` env prefix to init-project.sh invocation in cmd_init() (line 76)
- Added `CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun"` env prefix to profiles/*/apply.sh invocation; removed positional `$dryrun` arg (line 81)
- Sourced `lib/mutate.sh` after arg parsing with `DRY_RUN="$dryrun"` set so chokepoint works in the parent process
- Replaced bare `echo "$CONJURE_VERSION" > .conjure-version` with `mutate_write` + `mutate_summary`
- End-to-end verification: `conjure init --dry-run` emits 46 `[dry-run]` lines, no `.claude/` directory created
- 121 tests pass with no regressions

## Task Commits

1. **Task 1: Fix DRY_RUN threading in cmd_init()** - `edd37cf` (feat)

## Files Created/Modified

- `cli/conjure` — Added DRY_RUN env prefix to both subprocess invocations; sourced lib/mutate.sh after arg parsing with DRY_RUN set; replaced bare echo redirect with mutate_write + mutate_summary

## Decisions Made

1. **Set DRY_RUN before sourcing mutate.sh** — The plan spec said to source at the top of `cmd_init()` after local declarations. However, the source runs in the parent shell, not a subprocess, so `DRY_RUN` must be set as a shell variable before `mutate_write` and `mutate_summary` are called. Moving source to after the argument parsing loop (and setting `DRY_RUN="$dryrun"` there) ensures the chokepoint reads the correct flag value.

2. **Positional $dryrun arg removed from profile call** — All profiles now read `DRY_RUN` from the environment (set by the env prefix), not from a positional argument. This closes the two-sided bug: profiles were previously using `${2:-0}` to read a positional arg that was passed inconsistently.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Source lib/mutate.sh after arg parsing, not before**
- **Found during:** Task 1 (verification — dry-run test run)
- **Issue:** Placing `source "$CONJURE_HOME/lib/mutate.sh"` before the argument parsing `while` loop (as the plan specified) caused `mutate_write` at the end of `cmd_init()` to see `DRY_RUN` as unset (empty string), because `DRY_RUN` is a shell variable, not yet available at source time. The version stamp write fell through to the live-write path even during `--dry-run`, producing a "No such file or directory" error.
- **Fix:** Moved source line to after the argument parsing loop; added `DRY_RUN="$dryrun"` assignment immediately before source so the chokepoint reads the flag correctly.
- **Files modified:** cli/conjure
- **Verification:** `conjure init --dry-run` prints `[dry-run] would write .../.conjure-version` and no write error; SAFE-01 PASS confirmed
- **Committed in:** edd37cf (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in source placement)
**Impact on plan:** Essential for correctness — the chokepoint must see DRY_RUN to function. No scope creep.

## Issues Encountered

None beyond the auto-fixed source placement issue above.

## User Setup Required

None.

## Next Phase Readiness

- SAFE-01 is fully closed: `conjure init --dry-run` is end-to-end dry-run safe
- All mutation paths (init-project.sh, profiles, compliance overlays, version stamp) route through lib/mutate.sh
- Wave 3 (02-06: integration tests) can now add dry-run regression coverage to tests/run.sh

## Self-Check

- [x] `cli/conjure` — modified, committed in edd37cf
- [x] `bash -n cli/conjure` passes
- [x] `grep -c 'DRY_RUN.*bash.*init-project.sh' cli/conjure` returns 1
- [x] `grep -c 'DRY_RUN.*bash.*profiles' cli/conjure` returns 1
- [x] No positional `$dryrun` arg in profile apply.sh call
- [x] `mutate_write` used for version stamp
- [x] `mutate_summary` called in cmd_init
- [x] `source.*lib/mutate.sh` present in cmd_init
- [x] End-to-end dry-run test: `[dry-run]` lines emitted, no `.claude/` created (SAFE-01 PASS)
- [x] 121 tests pass (no regressions)

## Self-Check: PASSED

---
*Phase: 02-dry-run-enforcement-chokepoint*
*Completed: 2026-05-24*
