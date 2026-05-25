---
phase: 01-pre-flight-cross-platform-hooks
plan: 01
subsystem: testing
tags: [bash, preflight, os-detection, cross-platform, deps]

# Dependency graph
requires: []
provides:
  - scripts/preflight.sh: standalone dep checker with OS detection and required/optional dep split
  - conjure preflight: user-facing subcommand (D-07)
  - cmd_audit gate: preflight called first before audit-setup.sh (D-08)
affects: [phase-02, phase-03, phase-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OS detection via uname -s + uname -r + OSTYPE fallback (bash 3.2+ compatible)"
    - "Required/optional dep split: exit 1 on required missing, exit 0 on optional missing only"
    - "Per-OS fix-it lines: brew (macOS), apt (Linux/WSL), winget (Windows Git Bash)"
    - "Stub-delegate pattern: cmd_preflight() delegates to scripts/preflight.sh"

key-files:
  created:
    - scripts/preflight.sh
  modified:
    - cli/conjure
    - tests/run.sh

key-decisions:
  - "D-04/D-05: Required (node, git) exit 1; optional (jq, rg, shellcheck) warn and exit 0"
  - "D-07: conjure preflight is a user-facing subcommand exposed in dispatch and usage()"
  - "D-08: cmd_audit() calls cmd_preflight as first executable line before audit-setup.sh"
  - "D-09: cmd_init continues to call cmd_preflight || return 1 unchanged"
  - "D-10/D-11: One fix-it line per missing dep per detected OS (brew/apt/winget)"
  - "D-12: No auto-install — only printf fix-it strings, zero package-manager exec calls"

patterns-established:
  - "Self-contained scripts: preflight.sh has no sourced vars and no CONJURE_HOME dependency"
  - "Bash 3.2+ compat: no associative arrays, no mapfile/readarray — case statements only"
  - "Multi-path node strip in tests: strip all dirs containing node binary, not just first (accounts for fnm/nvm)"

requirements-completed: [SAFE-04]

# Metrics
duration: 3min
completed: 2026-05-24
---

# Phase 01 Plan 01: Pre-flight Extraction Summary

**Extracted cmd_preflight() into standalone scripts/preflight.sh with OS-detected fix-it lines (brew/apt/winget), required/optional dep split, and wired as user-facing `conjure preflight` subcommand and first gate in `conjure audit`**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-24T18:50:41Z
- **Completed:** 2026-05-24T18:53:41Z
- **Tasks:** 2
- **Files modified:** 3 (scripts/preflight.sh created, cli/conjure modified, tests/run.sh modified)

## Accomplishments
- Created self-contained `scripts/preflight.sh` with `_detect_os()` (uname-based) and `_fixup()` (per-dep, per-OS fix-it lines), bash 3.2+ compatible
- Required deps (node, git) cause exit 1; optional deps (jq, rg, shellcheck) warn and exit 0 — fulfills D-04/D-05
- Replaced inline `cmd_preflight()` body with a one-line stub-delegate; `conjure preflight` added to dispatch and usage()
- `cmd_audit()` now calls `cmd_preflight || return 1` as its first executable line (D-08)
- Added 4-assertion preflight test section to `tests/run.sh`: smoke, block-on-required, optional-missing exits 0, fix-it output grep
- All 117 tests pass (113 existing + 4 new preflight assertions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create scripts/preflight.sh** - `cd812d6` (feat)
2. **Task 2: Wire preflight into cli/conjure + tests/run.sh** - `18e6364` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `scripts/preflight.sh` - Standalone dep checker: OS detection, required/optional split, per-OS fix-it lines, exits 1 on required dep missing
- `cli/conjure` - cmd_preflight() replaced with stub-delegate; preflight added to usage() and dispatch; cmd_audit() gains preflight gate
- `tests/run.sh` - New "Preflight script" section with 4 assertions

## Decisions Made
- All 7 implementation decisions (D-04 through D-12) from CONTEXT.md followed as specified
- Bash 3.2+ compatibility enforced throughout (case statements instead of associative arrays)
- OS detection uses primary (uname -s/uname -r) with OSTYPE as Windows-only fallback

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Multi-path node strip in test assertion (b)**
- **Found during:** Task 2 (tests/run.sh preflight section)
- **Issue:** Plan's node-strip logic (`grep -v "^${NODE_DIR}$"`) only removes one PATH entry. On machines with fnm/nvm, node exists in 2-3 PATH entries (direct install path + multishell symlink + homebrew). Stripping one directory left node accessible via another, causing the "block-on-required" test to incorrectly pass (exit 0 instead of exit 1).
- **Fix:** Replaced single-directory grep filter with a while-read loop that strips ALL PATH entries containing an executable `node` binary: `while IFS= read -r dir; do [ -x "$dir/node" ] || printf '%s\n' "$dir"; done`
- **Files modified:** `tests/run.sh`
- **Verification:** `bash tests/run.sh` exits 0, "scripts/preflight.sh: correctly blocks when node missing" passes
- **Committed in:** `18e6364` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Necessary for correctness in fnm/nvm environments. The single-directory strip approach in the plan spec was insufficient for multi-install setups. Fix is strictly within scope of the test assertion.

## Issues Encountered
None beyond the fnm multi-path deviation documented above.

## Threat Model Verification
- T-01-02 (uname hang prevention): implemented via `uname -s 2>/dev/null || echo unknown`
- T-01-03 (no auto-install): verified — preflight.sh contains only printf fix-it strings, zero package-manager exec calls
- T-01-SC (no new packages): Phase 1 installs zero new packages; `dependencies: {}` remains empty

## Stub Scan
No stubs detected. All fix-it lines are static strings (not wired to dynamic data). No UI components.

## Threat Flags
None. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Next Phase Readiness
- `scripts/preflight.sh` is callable standalone from tests and CI
- `conjure preflight` is a working user-facing subcommand
- `conjure audit` is gated by preflight (D-08) — ready for Phase 2 (lib/mutate.sh + dry-run fix)
- All 117 tests green

## Self-Check: PASSED

---
*Phase: 01-pre-flight-cross-platform-hooks*
*Completed: 2026-05-24*
