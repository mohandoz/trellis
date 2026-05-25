---
phase: 03-sandboxed-per-profile-fixtures
plan: "03"
subsystem: testing
tags: [bash, fixtures, broken-fixture, sandbox, audit, run.sh, TEST-04]

# Dependency graph
requires:
  - phase: 03-01
    provides: tests/lib/sandbox.sh with sandbox_setup() interface
  - phase: 03-02
    provides: 9 audited-green profile fixtures under tests/fixtures/
provides:
  - tests/fixtures/_broken/ with 205-line CLAUDE.md triggering HARD CAP exceeded ERR
  - tests/fixtures/_broken/EXPECT with declarative assertion pattern
  - tests/run.sh extended with sandboxed fixture audit loop + broken fixture assertion
affects:
  - Phase 04 (golden-file loop — same run.sh structure; broken fixture serves as falsifiability anchor)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "underscore-prefix convention for intentionally-failing fixtures (_broken/)"
    - "declarative EXPECT file pattern: comments skipped with case match, blank lines skipped, each line is an extended-grep pattern"
    - "AUDIT_OUT/AUDIT_RC two-statement capture: exit code preserved without || true mask"
    - "[^_]*/ glob in for loop: shell-glob exclusion of underscore-prefix dirs"
    - "per-iteration trap reset: trap 'rm -rf SANDBOX_DIR' EXIT inside loop overwrites prior registration with current SANDBOX_DIR value"

key-files:
  created:
    - tests/fixtures/_broken/CLAUDE.md
    - tests/fixtures/_broken/EXPECT
    - tests/fixtures/_broken/.claude/ (copied from ts-next)
    - tests/fixtures/_broken/.claudeignore
    - tests/fixtures/_broken/.editorconfig
    - tests/fixtures/_broken/.env.example
    - tests/fixtures/_broken/.gitattributes
    - tests/fixtures/_broken/docs/
    - tests/fixtures/_broken/package.json
  modified:
    - tests/run.sh (source sandbox.sh + two new test sections)

key-decisions:
  - "ts-next .claude/ copied verbatim into _broken/ so audit-setup.sh passes early-exit guard (.claude/ missing check) and reaches CLAUDE.md size check"
  - "205 lines chosen for _broken CLAUDE.md (well above 201 threshold) — Pitfall 2 from RESEARCH.md: 105 lines triggers WARN/exit 1 not ERR/exit 2"
  - "EXPECT file uses minimal single pattern (HARD CAP exceeded) for Phase 3 — Phase 4 can extend with more patterns without changing assertions"
  - "fixture audit loop uses bash scripts/audit-setup.sh directly, not cli/conjure audit — eliminates preflight PATH non-determinism (T-03-13)"
  - "no || true on AUDIT_OUT/BROKEN_OUT capture lines — exit code preserved for assertion (T-03-14 mitigation)"

patterns-established:
  - "tests/fixtures/_broken/ naming convention: underscore-prefix marks intentionally-failing fixtures"
  - "EXPECT file format: # comment lines ignored, blank lines ignored, each active line is an extended grep pattern"
  - "Two-statement capture pattern: VAR=$(cmd 2>&1) then RC=$? — never combine with || true"

requirements-completed:
  - TEST-01
  - TEST-02
  - TEST-04

# Metrics
duration: 20min
completed: 2026-05-25
---

# Phase 3 Plan 03: Broken Fixture + Sandboxed Fixture Audit Sections Summary

**Intentionally-broken fixture (205-line CLAUDE.md triggering HARD CAP exceeded exit 2) and extended tests/run.sh with sandboxed fixture audit loop for all 9 green profiles plus specific-finding assertion for _broken — bash tests/run.sh exits 0 with PASS:136 FAIL:0**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-25T01:26:00Z
- **Completed:** 2026-05-25T01:46:00Z
- **Tasks:** 2
- **Files modified:** 45 (44 created, 1 modified)

## Accomplishments

- Created `tests/fixtures/_broken/` with 205-line CLAUDE.md (exceeds 200-line HARD CAP threshold), valid `.claude/` harness copied from ts-next, and `EXPECT` file containing the pattern `HARD CAP exceeded`
- `bash scripts/audit-setup.sh tests/fixtures/_broken` exits 2 with PASS: 16, FAIL: 1 — exactly one failure mode
- Extended `tests/run.sh` with source directive for `tests/lib/sandbox.sh` and two new test sections:
  - Green fixture loop: iterates all 9 profiles via `[^_]*/` glob under sandbox isolation, asserts exit 0 (TEST-01, TEST-02)
  - Broken fixture assertion: runs _broken under sandbox, asserts non-zero exit + EXPECT pattern grep (TEST-04)
- `bash tests/run.sh` exits 0 with PASS: 136 FAIL: 0 — 11 new assertions added above pre-phase baseline
- All three phase requirements verified green by the test suite: TEST-01 (fixtures exist), TEST-02 (sandbox isolation), TEST-04 (specific finding assertion)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create tests/fixtures/_broken/** - `f320898` (feat)
2. **Task 2: Extend tests/run.sh with sandboxed fixture audit sections** - `98241d9` (feat)

## Files Created/Modified

- `tests/fixtures/_broken/CLAUDE.md` — 205-line intentionally-oversized CLAUDE.md; no @imports; triggers HARD CAP exceeded ERR
- `tests/fixtures/_broken/EXPECT` — declarative EXPECT file; single active pattern: `HARD CAP exceeded`
- `tests/fixtures/_broken/.claude/` — full harness copied from ts-next (settings.json + 5 .mjs hooks + 19 skills + 6 agents)
- `tests/fixtures/_broken/.claudeignore`, `.editorconfig`, `.env.example`, `.gitattributes`, `docs/`, `package.json` — ancillary files from ts-next so all audit checks except CLAUDE.md size pass
- `tests/run.sh` — added `source tests/lib/sandbox.sh` directive; two new sections before summary block

## Decisions Made

- Copied ts-next `.claude/` verbatim rather than creating a minimal harness — ensures all 16 PASS checks in audit output come from real harness content, isolating the single FAIL to the CLAUDE.md size check
- Used 205 lines (not exactly 201) for safety margin — file won't accidentally slip below threshold if edited during development
- EXPECT file format uses `case "$pattern" in \#*)` for comment skipping — POSIX-compatible without `[[ ]]` bash-ism, matching run.sh style
- Two-statement capture (`VAR=$(cmd 2>&1)` then `RC=$?`) mandated by plan and enforced — avoids T-03-14 threat where `|| true` masks the real exit code

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all files are functional test artifacts, not placeholders.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundaries introduced. The _broken fixture is a static committed directory. Sandbox isolation (T-03-09) is in effect for all audit invocations via sandbox_setup(). Vacuous EXPECT pattern threat (T-03-10) mitigated: blank/comment lines explicitly skipped, at least one concrete pattern enforced.

## Self-Check: PASSED

- [x] `tests/fixtures/_broken/CLAUDE.md` exists with 205 lines (wc -l confirms ≥201)
- [x] `bash scripts/audit-setup.sh tests/fixtures/_broken` exits 2 with "HARD CAP exceeded" in output and FAIL: 1
- [x] `tests/fixtures/_broken/EXPECT` contains `HARD CAP exceeded` (grep -q confirmed)
- [x] `tests/fixtures/_broken/.claude/settings.json` exists
- [x] `tests/fixtures/_broken/.claude/hooks/` contains 5 .mjs files
- [x] `grep -c '^@' tests/fixtures/_broken/CLAUDE.md` = 0 (no @imports)
- [x] `grep -n 'source.*tests/lib/sandbox.sh' tests/run.sh` matches at line 8
- [x] `bash tests/run.sh` exits 0 with PASS: 136 FAIL: 0
- [x] Output contains `fixture audit green: ts-next`
- [x] Output contains `_broken: found expected finding: HARD CAP exceeded`
- [x] Commit f320898 exists (Task 1)
- [x] Commit 98241d9 exists (Task 2)

---
*Phase: 03-sandboxed-per-profile-fixtures*
*Completed: 2026-05-25*
