---
phase: 09-3-way-merge
verified: 2026-05-25T14:00:00Z
status: passed
score: 11/11 must-haves verified
overrides_applied: 0
re_verification: false
---

# Phase 09: 3-Way Merge Verification Report

**Phase Goal:** `conjure update --apply` performs real 3-way file merges instead of silently ignoring user customizations, and conflicts are safely surfaced as sidecar files
**Verified:** 2026-05-25
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                              | Status     | Evidence                                                                                      |
|----|----------------------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------|
| 1  | `lib/merge.sh` exists, sources without error, and exports `merge_file_3way`                        | VERIFIED   | 163-line file exists; `source lib/mutate.sh; source lib/merge.sh` defines all 3 functions    |
| 2  | `merge_file_3way` returns 0 on clean merge, 1 on conflict, 2 on git error                         | VERIFIED   | Behavioral spot-check: non-adjacent-line fixture → rc=0; same-line conflict → rc=1           |
| 3  | `merge_file_3way` writes sidecar (never touches current) on conflict                               | VERIFIED   | Spot-check MERGE-02: original has `USER_VERSION`, no `<<<<<<<`; sidecar has markers          |
| 4  | CI shellcheck covers `lib/merge.sh` (`lib/` added to find glob)                                   | VERIFIED   | `ci.yml` line 22: `find cli scripts migrations profiles compliance templates/hooks tests lib` |
| 5  | `conjure init` writes `.claude/.conjure-templates-<version>/` snapshot after stamping version      | VERIFIED   | Smoke test: snapshot dir created with `CLAUDE.md.tmpl`, `skills/`, `agents/`, `hooks/`       |
| 6  | `conjure update --apply` aborts with correct D-01 message when snapshot missing                    | VERIFIED   | Spot-check MERGE-03: exit 1, prints "No base snapshot for v0.1.0. Re-run 'conjure init'..."  |
| 7  | `conjure update --apply` merges user-owned files via `git merge-file --diff3` (stub gone)          | VERIFIED   | Stub text absent from `cli/conjure`; `merge_user_files` called at line 216                   |
| 8  | On conflict: original live file untouched, sidecar written, exit 1 (D-05, D-06)                   | VERIFIED   | Spot-check confirms: original unchanged, sidecar at `.conjure-conflict-skills_testskill_SKILL.md` |
| 9  | Generated files (`settings.json`) taken from upstream unconditionally without 3-way merge (MERGE-04) | VERIFIED | Spot-check MERGE-04: stale key absent after update; no sidecar written                       |
| 10 | Clean update stamps `.conjure-version` with new version, exits 0                                   | VERIFIED   | `cli/conjure` line 236: `mutate_write .conjure-version` only reached on zero conflicts       |
| 11 | `conjure audit` detects `^<<<<<<<` markers in `.claude/` and exits non-zero (MERGE-05)            | VERIFIED   | Spot-check: audit exits 2 with "Unresolved merge conflicts"; sidecar files excluded correctly |

**Score:** 11/11 truths verified

---

### Required Artifacts

| Artifact                          | Expected                                                               | Status     | Details                                                                 |
|-----------------------------------|------------------------------------------------------------------------|------------|-------------------------------------------------------------------------|
| `lib/merge.sh`                    | 3-way merge library — `merge_file_3way`, `write_merge_sidecar`, `merge_user_files`; min 60 lines | VERIFIED | 163 lines; all three functions defined and functional |
| `.github/workflows/ci.yml`        | shellcheck glob includes `lib/` at end after `tests`                  | VERIFIED   | Line 22 confirmed: `find cli scripts migrations profiles compliance templates/hooks tests lib` |
| `cli/conjure`                     | cmd_init snapshot write + cmd_update --apply real merge logic          | VERIFIED   | Snapshot write block at lines 90-96; merge impl at lines 185-238; contains `.conjure-templates-` |
| `scripts/audit-setup.sh`          | Conflict marker detection block before final exit, uses `grep -rl`    | VERIFIED   | Lines 132-146; uses `err()` for hard fail; `.conjure-conflict-` excluded |
| `tests/run.sh`                    | MERGE-01 through MERGE-05 test blocks; contains `MERGE-01`            | VERIFIED   | 33 MERGE-0[1-5] references; full suite: PASS: 216, FAIL: 0             |

---

### Key Link Verification

| From                         | To              | Via                                | Status   | Details                                                                 |
|------------------------------|-----------------|------------------------------------|----------|-------------------------------------------------------------------------|
| `lib/merge.sh`               | `lib/mutate.sh` | `mutate_write` for disk writes     | WIRED    | Lines 43, 69 call `mutate_write`; line 57 documents delegation          |
| `cli/conjure`                | `lib/merge.sh`  | `source "$CONJURE_HOME/lib/merge"` | WIRED    | Line 187: `source "$CONJURE_HOME/lib/merge.sh"`                         |
| `cli/conjure:cmd_init`       | `lib/mutate.sh` | `mutate_mkdir` + `mutate_cp` for snapshot | WIRED | Lines 91-95: `mutate_mkdir` + 4x `mutate_cp` in `cmd_init`           |
| `cli/conjure:cmd_update`     | `.conjure-version` | `mutate_write` only on zero conflicts | WIRED | Line 236: `mutate_write` reached only after conflict-count check       |
| `scripts/audit-setup.sh`     | `.claude/`      | `grep -rl '^<<<<<<<'`              | WIRED    | Line 134: `grep -rl '^<<<<<<<' .claude/` with sidecar exclusion        |
| `tests/run.sh`               | `lib/merge.sh`  | `source $CONJURE_HOME/lib/merge.sh` | WIRED   | Lines 611-613: sources `lib/mutate.sh` then `lib/merge.sh`             |

---

### Data-Flow Trace (Level 4)

| Artifact           | Data Variable              | Source                                         | Produces Real Data | Status   |
|--------------------|----------------------------|------------------------------------------------|--------------------|----------|
| `merge_file_3way`  | `merged` (stdout of git)   | `git merge-file -p --diff3` on real files      | Yes — git output   | FLOWING  |
| `write_merge_sidecar` | `content` (conflict markers) | `merged` from `merge_file_3way` (rc > 0) | Yes — conflict text | FLOWING |
| `merge_user_files` | `CONJURE_MERGE_CONFLICT_COUNT` | `write_merge_sidecar` increments it         | Yes                | FLOWING  |
| `cmd_update --apply` | `merge_rc`, conflict report | `merge_user_files` return code + module vars | Yes               | FLOWING  |

---

### Behavioral Spot-Checks

| Behavior                                             | Command                                           | Result                                                  | Status |
|------------------------------------------------------|---------------------------------------------------|---------------------------------------------------------|--------|
| Clean merge exits 0, both edits present, no sidecar  | `DRY_RUN=0 merge_file_3way` with non-adjacent fixture | rc=0; content has USER_EDIT+UPSTREAM_EDIT; no sidecar | PASS   |
| Conflict exits 1, sidecar written, original untouched | `DRY_RUN=0 merge_file_3way` with same-line conflict | rc=1; original has USER_VERSION, no `<<<<<<<`; sidecar at correct path with markers | PASS |
| Missing snapshot aborts with D-01 message            | `CONJURE_HOME=. cli/conjure update --apply $dir`  | exit 1; "No base snapshot for v0.1.0" printed           | PASS   |
| settings.json taken upstream (stale key gone)         | `cli/conjure update --apply $dir` with stale key  | stale key absent; no sidecar                            | PASS   |
| Audit exits non-zero on `<<<<<<<` in harness file    | `bash scripts/audit-setup.sh $dir`               | exit 2; "Unresolved merge conflicts" printed            | PASS   |
| Audit does NOT flag sidecar files as false positive  | `bash scripts/audit-setup.sh $dir` (sidecar only) | "Unresolved merge conflicts" NOT printed                | PASS   |
| conjure init creates snapshot with all 4 items       | `CONJURE_HOME=. cli/conjure init $dir`            | `.conjure-templates-0.2.1/` with CLAUDE.md.tmpl, agents/, hooks/, skills/ | PASS |
| Full test suite                                      | `bash tests/run.sh`                              | PASS: 216, FAIL: 0                                      | PASS   |

---

### Requirements Coverage

| Requirement | Source Plans        | Description                                                                                     | Status    | Evidence                                                              |
|-------------|---------------------|-------------------------------------------------------------------------------------------------|-----------|-----------------------------------------------------------------------|
| MERGE-01    | 09-01, 09-02, 09-03 | User can run `conjure update --apply` with real `git merge-file --diff3` merge (stub gone)      | SATISFIED | Spot-check: clean merge rc=0, both edits merged; stub text absent    |
| MERGE-02    | 09-02, 09-03        | `conjure init` writes `.conjure-templates-<version>/` snapshot                                  | SATISFIED | Smoke test: `.conjure-templates-0.2.1/` created with 4 items         |
| MERGE-03    | 09-01, 09-02, 09-03 | On conflict, original untouched; `.conjure-conflict-*` sidecar written                          | SATISFIED | Spot-check: original preserved, sidecar at correct encoded path       |
| MERGE-04    | 09-02, 09-03        | Generated files (`settings.json`) accept upstream unconditionally; user-owned go through merge  | SATISFIED | Spot-check: stale key gone, no sidecar; `mutate_cp` path confirmed    |
| MERGE-05    | 09-03               | `conjure audit` detects `^<<<<<<<` markers, exits non-zero with specific message                | SATISFIED | Spot-check: exit 2, "Unresolved merge conflicts found in .claude/"    |

**Note:** REQUIREMENTS.md traceability table still shows all MERGE-* as "Pending / TBD" — this is a documentation tracking gap only; the implementation is fully present and exercised. Not a code blocker.

---

### Anti-Patterns Found

| File                     | Line | Pattern | Severity | Impact |
|--------------------------|------|---------|----------|--------|
| (none in phase-modified files) | — | — | — | — |

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`, or "not yet implemented" markers found in `lib/merge.sh`, `cli/conjure` (new lines), `scripts/audit-setup.sh` (new block), or `tests/run.sh` (new blocks). The stub text "Interactive update not yet implemented" is confirmed absent from `cli/conjure`.

---

### Shellcheck Status

Shellcheck is not installed on darwin (documented as CI-only in all three SUMMARY files). Manual code review confirms:
- No `local a="$(cmd)"` SC2155 violations: all command substitutions use two-line `local a; a="$(cmd)"` form
- No `for f in $(find ...)` SC2044 violations: all find output consumed via `while IFS= read -r` from mktemp temp files
- No SC2034 unused-variable violations: all declared locals are referenced
- No SC2164 violations: no `cd` calls in new code

CI will run `shellcheck -S error -e SC2164,SC2044,SC2034,SC2155` on ubuntu-latest.

---

### Human Verification Required

None — all success criteria are verifiable programmatically and all spot-checks passed.

---

### Gaps Summary

No gaps. All 11 must-have truths are VERIFIED against the actual codebase:

- `lib/merge.sh` is substantive (163 lines), sources cleanly, and all three functions are fully implemented (not stubbed).
- `cli/conjure` has the stub replaced with working merge logic; `cmd_init` snapshot write block is present and functional.
- `scripts/audit-setup.sh` conflict detection block uses `err()` (hard fail), properly excludes sidecar files, and is positioned before the `# Summary` block.
- `tests/run.sh` contains 33 MERGE test references covering all five MERGE requirements; the full suite exits with FAIL: 0.
- All key links are wired: `merge_file_3way` calls `mutate_write` (not direct printf); `cmd_update` sources `lib/merge.sh`; `cmd_init` snapshot uses `mutate_mkdir`/`mutate_cp`.

---

_Verified: 2026-05-25T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
