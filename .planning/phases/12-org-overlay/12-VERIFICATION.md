---
phase: 12-org-overlay
verified: 2026-05-26T00:30:00Z
status: passed
score: 12/12 must-haves verified
overrides_applied: 0
re_verification: false
---

# Phase 12: Org Overlay Verification Report

**Phase Goal:** An organization can define a private overlay repo that is applied on top of the base kit, with full audit traceability and credential-safe re-pull support
**Verified:** 2026-05-26T00:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

All five ROADMAP success criteria and all plan must-haves verified against codebase.

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | `conjure init --overlay <git-url>` routes to `scripts/init-overlay.sh` after base kit; all writes via `lib/mutate.sh` | VERIFIED | `cli/conjure:91-94` — `init-overlay.sh "$overlay" "$target"` call inside `if [ -n "$overlay" ]` block after profile overlay; `init-overlay.sh` sources `lib/mutate.sh` and uses `mutate_cp` + `mutate_write` exclusively |
| 2  | After `conjure init --overlay`, `.claude/.conjure-org-overlay` records overlay URL and cloned commit SHA | VERIFIED | `init-overlay.sh:59-61` — `mutate_write` called with `printf 'url=%s\nsha=%s'` after copy loop; SHA captured via `git rev-parse HEAD`; marker written AFTER copy (line 59 > line 54) |
| 3  | `conjure refresh-overlay` re-pulls and re-applies overlay; exits 1 with correct message when no marker | VERIFIED | `cli/conjure:265-266,329` — `cmd_refresh_overlay()` calls `refresh-overlay.sh`; dispatch case `refresh-overlay)` present; `refresh-overlay.sh:35-38` — exits 1 with exact "No org overlay configured" message; backup-before-mutate at lines 46-54 |
| 4  | `conjure audit` reports overlay presence, pinned SHA, and drift from upstream overlay HEAD; exits 0 when `git ls-remote` fails | VERIFIED | `audit-setup.sh:147-164` — full overlay section reads marker, reports `url:` + `pinned:`, runs `git ls-remote ... \|\| true`; prints `DRIFT` or `up to date` or `drift check skipped`; section is between conflict-marker block (line 145) and `# Summary` (line 166) |
| 5  | Overlay authentication uses git credential store; no credentials stored by Conjure | VERIFIED | `grep -cE 'password\|credential\|token'` returns 0 on both worker scripts; DISPLAY_URL masking via `sed 's\|//[^@]*@\|//***@\|'` — raw URL never echoed to stdout |
| 6  | Running `bash scripts/init-overlay.sh <url> <target>` exits 0, copies overlay files, writes marker | VERIFIED | `init-overlay.sh` confirmed substantive: 65 lines, clone → find loop → mutate_cp → marker write sequence; test suite OVLY-01/02 assertions green (PASS: 261 FAIL: 0) |
| 7  | No `.git/` directory appears inside `.claude/` after init or refresh | VERIFIED | Both scripts: `find "$CLONE_TMP" -mindepth 1 -maxdepth 1 ! -name '.git'` — Pitfall 1 guard confirmed in source |
| 8  | Both scripts pass shellcheck (error-severity) | VERIFIED | `shellcheck -S error scripts/init-overlay.sh` → exit 0; `shellcheck -S error scripts/refresh-overlay.sh` → exit 0 |
| 9  | `conjure refresh-overlay` exits 1 with "No org overlay configured" when no marker | VERIFIED | `refresh-overlay.sh:35-38` — exact message `✗ No org overlay configured. Run conjure init --overlay <git-url> first.`; OVLY-03 test assertions green |
| 10 | `conjure audit` exits 0 (not 128) on `git ls-remote` failure | VERIFIED | `audit-setup.sh:156` — `|| true` on `git ls-remote` line; OVLY-04 test checks `AUDIT_SKIP_RC -ne 128`; test assertion green |
| 11 | All OVLY-01..OVLY-05 are exercised by named regression tests in `tests/run.sh` | VERIFIED | 93 OVLY label occurrences; 18 pass/fail assertions across all 5 requirement groups; `bash tests/run.sh` exits 0 with `FAIL: 0` (261 total passes) |
| 12 | Mock overlay uses `file://` — no network required in regression tests | VERIFIED | `tests/run.sh:1091` — `OVLY_URL="file://$OVLY_REPO"`; 3 `file://` occurrences in test file |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/init-overlay.sh` | Clone + apply overlay worker | VERIFIED | 65 lines; `git clone --depth 1`; process substitution find loop; `mutate_cp`; `mutate_write .conjure-org-overlay`; `printf 'url=%s\nsha=%s'`; `rev-parse HEAD`; no credential keywords |
| `scripts/refresh-overlay.sh` | Re-pull overlay worker | VERIFIED | 80 lines; marker-not-found guard (exit 1); `cut -d= -f2-` for URL; backup `cp -R` guarded by DRY_RUN; `git clone --depth 1`; process substitution; `mutate_cp`; `mutate_write`; no credential keywords |
| `cli/conjure` | CLI entry points for --overlay and refresh-overlay | VERIFIED | `overlay=""` local decl (line 56); `--overlay=*)` case arm (line 61); `init-overlay.sh "$overlay" "$target"` call (line 93); `cmd_refresh_overlay()` function (line 265); `refresh-overlay)` dispatch (line 329); usage string updated (lines 33,39) |
| `scripts/audit-setup.sh` | Overlay presence + drift check | VERIFIED | Lines 147-164; reads `.conjure-org-overlay`; `git ls-remote ... \|\| true`; `DRIFT`/`up to date`/`drift check skipped` paths; section correctly positioned between conflict-marker block and `# Summary` |
| `tests/run.sh` | OVLY regression test blocks | VERIFIED | 171 lines inserted; OVLY-SETUP with file:// local git repo; 18 assertions across OVLY-01..OVLY-05; full cleanup `rm -rf "$OVLY_REPO" "$OVLY_TARGET"` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/init-overlay.sh` | `lib/mutate.sh` | `source $CONJURE_HOME/lib/mutate.sh` | WIRED | Line 17; `mutate_cp` at line 53; `mutate_write` at line 59 |
| `scripts/refresh-overlay.sh` | `.claude/.conjure-org-overlay` | `grep '^url=' marker \| cut -d= -f2-` | WIRED | Line 40; URL parsed from marker before re-clone |
| `cli/conjure cmd_init` | `scripts/init-overlay.sh` | `bash $CONJURE_HOME/scripts/init-overlay.sh $overlay $target` | WIRED | Line 93; inside `if [ -n "$overlay" ]` guard |
| `cli/conjure cmd_refresh_overlay` | `scripts/refresh-overlay.sh` | `bash $CONJURE_HOME/scripts/refresh-overlay.sh` | WIRED | Line 266; dispatch case at line 329 |
| `scripts/audit-setup.sh` | `.claude/.conjure-org-overlay` | `grep '^url='` and `grep '^sha='` reads | WIRED | Lines 152-153; URL and SHA read into `OVERLAY_URL` / `PINNED_SHA` variables, used in `note`/`warn`/`ok` output |
| `tests/run.sh OVLY block` | `scripts/init-overlay.sh` | `bash "$CONJURE_HOME/scripts/init-overlay.sh" "$OVLY_URL" "$OVLY_TARGET"` | WIRED | Line 1101; CONJURE_HOME prefix used |
| `tests/run.sh OVLY block` | `scripts/audit-setup.sh` | `bash "$CONJURE_HOME/scripts/audit-setup.sh" "$OVLY_TARGET"` | WIRED | Lines 1192, 1202, 1216 |

### Data-Flow Trace (Level 4)

All modified files are bash scripts with direct file I/O — not components with state/props. Data flows are deterministic and traced above. No React/web data-flow patterns apply.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `audit-setup.sh overlay section` | `OVERLAY_URL`, `PINNED_SHA` | `grep` on `.conjure-org-overlay` flat file | Yes — reads actual marker content written by `init-overlay.sh` | FLOWING |
| `audit-setup.sh drift check` | `UPSTREAM_SHA` | `git ls-remote "$OVERLAY_URL" HEAD` | Yes — real network query; graceful empty on failure | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite exits 0 | `bash tests/run.sh` | `PASS: 261 FAIL: 0` | PASS |
| shellcheck -S error on init-overlay.sh | `shellcheck -S error scripts/init-overlay.sh` | exit 0 | PASS |
| shellcheck -S error on refresh-overlay.sh | `shellcheck -S error scripts/refresh-overlay.sh` | exit 0 | PASS |
| shellcheck -S error on cli/conjure | `shellcheck -S error cli/conjure` | exit 0 | PASS |
| shellcheck -S error on audit-setup.sh | `shellcheck -S error scripts/audit-setup.sh` | exit 0 | PASS |
| No credential keywords in init-overlay.sh | `grep -cE 'password\|credential\|token' scripts/init-overlay.sh` | 0 | PASS |
| No credential keywords in refresh-overlay.sh | `grep -cE 'password\|credential\|token' scripts/refresh-overlay.sh` | 0 | PASS |

### Probe Execution

No `probe-*.sh` files declared in any PLAN; Plan 03 explicitly uses `bash tests/run.sh` as its verification — captured above. No separate probe execution needed.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| OVLY-01 | 12-01, 12-02, 12-03 | `conjure init --overlay <git-url>` applies base kit then overlay; all writes via `lib/mutate.sh` | SATISFIED | `cli/conjure:91-94` routes to `init-overlay.sh`; `init-overlay.sh` uses `mutate_cp`/`mutate_write` exclusively |
| OVLY-02 | 12-01, 12-03 | `.claude/.conjure-org-overlay` marker records URL and commit SHA | SATISFIED | `init-overlay.sh:59-61` writes marker with url= and sha= after successful copy |
| OVLY-03 | 12-01, 12-02, 12-03 | `conjure refresh-overlay` re-pulls and re-applies; exits 1 on missing marker | SATISFIED | `refresh-overlay.sh:35-38` exits 1; `cmd_refresh_overlay` + dispatch in `cli/conjure` |
| OVLY-04 | 12-02, 12-03 | `conjure audit` reports overlay presence, pinned SHA, and drift | SATISFIED | `audit-setup.sh:147-164`; drift, up-to-date, and skip paths all implemented and tested |
| OVLY-05 | 12-01, 12-02, 12-03 | Overlay auth via git credential store; no credentials stored by Conjure | SATISFIED | `grep -cE 'password\|credential\|token'` returns 0 on both worker scripts; URL masking via sed |

**All 5 OVLY requirement IDs are claimed by at least one plan and verified in codebase. No orphaned requirements.**

**Note on REQUIREMENTS.md traceability table:** OVLY-01..OVLY-05 rows still show `Status: Pending` in the table (the table tracks completion but was not updated by the executor). This is a documentation gap only — does not affect implementation status.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

No TBD/FIXME/XXX/TODO/placeholder markers found in any of the five modified files. No empty implementations. No hardcoded empty returns in non-test context. All stubs from prior phases remain outside the scope of this phase.

### Human Verification Required

None. All behaviors verifiable programmatically. The test suite runs entirely offline using `file://` local git repos. Drift detection was verified by overwriting the marker with a fake SHA and confirming `DRIFT` output.

### Gaps Summary

No gaps found. All 12 observable truths verified. All 5 required artifacts exist, are substantive, and are wired. All 5 OVLY requirements satisfied. `bash tests/run.sh` exits 0 with FAIL: 0 (261 passes). All four modified files pass `shellcheck -S error`. No credential keywords in any worker script. Phase goal is fully achieved.

---

_Verified: 2026-05-26T00:30:00Z_
_Verifier: Claude (gsd-verifier)_
