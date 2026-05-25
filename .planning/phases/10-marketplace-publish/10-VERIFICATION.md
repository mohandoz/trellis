---
phase: 10-marketplace-publish
verified: 2026-05-25T00:00:00Z
status: human_needed
score: 18/18 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run `claude plugin validate .` from repo root"
    expected: "Exit 0 with 0 errors (at most the informational CLAUDE.md advisory warning)"
    why_human: "Requires the claude CLI binary which is not available in this verification environment"
  - test: "Run `claude plugin validate .claude-plugin/plugin.json` from repo root"
    expected: "Exit 0 with 0 errors (at most 1 warning about CLAUDE.md not loaded)"
    why_human: "Requires the claude CLI binary which is not available in this verification environment"
---

# Phase 10: Marketplace Publish — Verification Report

**Phase Goal:** The Conjure plugin manifest is valid, version-consistent, and a developer can run `conjure publish` to update and submit it to the community catalog
**Verified:** 2026-05-25
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `conjure publish` updates marketplace.json SHA to HEAD SHA | VERIFIED | `scripts/publish-plugin.sh` lines 85-88: `jq --arg sha "$CURRENT_SHA" ... '.plugins[0].source.sha = $sha ...'`; mutate_write call at line 105; MKTPL-01 SHA test passes in test suite (227 PASS, 0 FAIL) |
| 2 | `conjure publish` updates marketplace.json .plugins[0].version to VERSION | VERIFIED | `scripts/publish-plugin.sh` line 87: `.plugins[0].version = $ver`; test suite confirms `.plugins[0].version` matches VERSION after live run |
| 3 | `conjure publish` updates plugin.json .version to VERSION | VERIFIED | `scripts/publish-plugin.sh` lines 94-96: `jq --arg ver "$CURRENT_VERSION" '.version = $ver'` |
| 4 | `conjure publish` aborts with exit code 2 when working tree is dirty | VERIFIED | `publish-plugin.sh` lines 63-66: `git diff --quiet || git diff --cached --quiet`; exit 2; MKTPL dirty-tree test passes |
| 5 | `conjure publish --dry-run` prints mutations without writing files | VERIFIED | DRY_RUN=1 path flows through `mutate_write` in `lib/mutate.sh` which prints `[dry-run] would write`; test confirms marketplace.json byte-for-byte identical after dry-run |
| 6 | `conjure publish --submit` writes .claude-plugin/submit-entry.json | VERIFIED | `publish-plugin.sh` lines 111-134: CONJURE_SUBMIT=1 path builds JSON via jq -n and calls mutate_write; test confirms file exists |
| 7 | `conjure publish --submit` prints a checklist with submission URL | VERIFIED | Lines 138-147 print checklist including `https://claude.ai/settings/plugins/submit`; MKTPL-04 URL test passes |
| 8 | All writes go through mutate_write (DRY_RUN honored) | VERIFIED | `publish-plugin.sh` sources `lib/mutate.sh` at line 18; all three write paths (marketplace.json, plugin.json, submit-entry.json) call mutate_write |
| 9 | CI fails if marketplace.json .plugins[0].version does not match VERSION | VERIFIED | `ci.yml` lines 32-38: step "Check version consistency" uses `jq -r '.plugins[0].version // empty'`; rc=1 on mismatch; exit "$rc" |
| 10 | CI fails if plugin.json .version does not match VERSION | VERIFIED | Same step: `jq -r '.version // empty'`; rc=1 on mismatch |
| 11 | CI runs `claude plugin validate .` from repo root | VERIFIED | `ci.yml` line 54: `claude plugin validate .` in "Validate plugin manifests" step |
| 12 | CI runs `claude plugin validate .claude-plugin/plugin.json` explicitly | VERIFIED | `ci.yml` line 55: `claude plugin validate .claude-plugin/plugin.json` |
| 13 | Claude CLI install failure causes CI failure | VERIFIED | `ci.yml` "Install claude CLI" step has no `continue-on-error`; final line is `claude --version` which gates the step |
| 14 | New steps appear in the existing test job, not a new job | VERIFIED | Steps at lines 30-55 are inside the `test` job; no new top-level job added |
| 15 | marketplace.json has valid owner object and plugins[] array | VERIFIED | File confirmed: `.owner.name = "mohandoz"`, `.plugins[0].name = "conjure"` |
| 16 | plugin.json author is an object | VERIFIED | `jq -r '.author | type'` returns "object"; `.author.name = "mohandoz"` |
| 17 | marketplace.json .plugins[0].source.source = "github" | VERIFIED | Confirmed: `jq -r '.plugins[0].source.source'` = "github" |
| 18 | `tests/run.sh` passes with 0 failures (all MKTPL assertions) | VERIFIED | Live run: 227 PASS, 0 FAIL; all 10 MKTPL assertions show checkmark |

**Score:** 18/18 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.claude-plugin/marketplace.json` | Valid marketplace manifest with owner + plugins[] structure | VERIFIED | File exists; owner object present; plugins[0].version = "0.2.1"; source.source = "github"; repo = "mohandoz/conjure" |
| `.claude-plugin/plugin.json` | Valid plugin manifest with author object, no mcpServers | VERIFIED | File exists; author type = object; .version = "0.2.1"; mcpServers absent; agents array with ./ prefix |
| `scripts/publish-plugin.sh` | Worker script with mutate_write, dirty-tree check, submit path | VERIFIED | File exists; executable (-rwxr-xr-x); 150 lines; sources lib/mutate.sh; mutate_write calls for all 3 output files; mutate_summary as final statement |
| `.github/workflows/ci.yml` | Three new steps in test job: version-consistency, claude CLI install, manifest validate | VERIFIED | Steps at lines 30-55 in test job; correct ordering (after Validate JSON, before Run kit test suite) |
| `tests/run.sh` | Inline regression tests for all MKTPL requirements | VERIFIED | MKTPL section at line 758; 10 MKTPL assertions; all pass (227/0) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `cli/conjure cmd_publish` | `scripts/publish-plugin.sh` | env-prefix bash invocation | VERIFIED | Line 276-277: `CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" CONJURE_SUBMIT="$do_submit" bash "$CONJURE_HOME/scripts/publish-plugin.sh"` |
| `scripts/publish-plugin.sh` | `lib/mutate.sh` | source | VERIFIED | Line 18: `source "$CONJURE_HOME/lib/mutate.sh"` |
| `scripts/publish-plugin.sh` | `.claude-plugin/marketplace.json` | jq --arg + mutate_write | VERIFIED | Lines 85-108: jq mutation with --arg sha/ver; mutate_write call at line 105 |
| `marketplace.json .plugins[0].source` | github repo mohandoz/conjure | source.source field | VERIFIED | `.plugins[0].source.source = "github"`, `.plugins[0].source.repo = "mohandoz/conjure"` |
| `plugin.json .author` | object with name key | author.name field | VERIFIED | `.author.name = "mohandoz"`; type = object |
| `ci.yml test job` | VERSION + .claude-plugin/*.json | bash version-consistency check step | VERIFIED | `jq -r '.plugins[0].version // empty'` pattern at ci.yml line 33 |
| `ci.yml test job` | claude plugin validate | claude CLI installed via apt signed repo | VERIFIED | Signed apt repo with GPG key; no continue-on-error; claude --version as install gate |
| `tests/run.sh MKTPL section` | `scripts/publish-plugin.sh` | script-copy sandbox isolation | VERIFIED | Copies script+lib into mktemp sandbox; invokes sandbox copy (CONJURE_HOME self-resolves from script path) |
| `tests/run.sh version-consistency section` | jq + VERSION comparison logic | inline bash reproducing CI check | VERIFIED | Line 824-831: reproduces exact CI logic with `.plugins[0].version // empty` |

### Data-Flow Trace (Level 4)

Not applicable. Phase artifacts are shell scripts and JSON manifests — no component that renders dynamic UI data.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `conjure publish --help` exits 0 | `cli/conjure publish --help` | Prints usage, exit 0 | PASS |
| `publish-plugin.sh` bash syntax valid | `bash -n scripts/publish-plugin.sh` | No errors | PASS |
| `cli/conjure` bash syntax valid | `bash -n cli/conjure` | No errors | PASS |
| `tests/run.sh` 0 failures | `bash tests/run.sh` | 227 PASS, 0 FAIL | PASS |
| Version consistency | `jq + cat VERSION` | All three sources = "0.2.1" | PASS |
| cmd_publish dispatch | `grep 'publish)' cli/conjure` | Line 297 present | PASS |
| `claude plugin validate .` | Requires claude CLI binary | Not runnable in this environment | SKIP — see Human Verification |

### Probe Execution

No probes declared in PLAN files. No conventional `scripts/*/tests/probe-*.sh` found for this phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MKTPL-01 | 10-01, 10-02, 10-04 | `conjure publish` updates marketplace.json SHA + validates locally | SATISFIED | `scripts/publish-plugin.sh` performs jq SHA/version update via mutate_write; manifests are structurally valid; 5 MKTPL-01 tests pass |
| MKTPL-02 | 10-03, 10-04 | CI validates version fields match VERSION file on every PR | SATISFIED | `ci.yml` "Check version consistency" step with `// empty` fallback; drift-detection test passes |
| MKTPL-03 | 10-03 | CI runs `claude plugin validate .` and fails on schema errors | SATISFIED | `ci.yml` "Validate plugin manifests" step with two separate invocations; no --strict; no continue-on-error |
| MKTPL-04 | 10-02, 10-04 | `conjure publish --submit` produces checklist + submission URL | SATISFIED | submit-entry.json written via mutate_write; 7-item checklist printed including `claude.ai/settings/plugins/submit`; 3 MKTPL-04 tests pass |

Note: The REQUIREMENTS.md traceability table still shows "TBD" / "Pending" for MKTPL-01 through MKTPL-04 — this is a stale table. The checkbox column at the top of the requirements section correctly shows `[x]` for all four. The traceability table should be updated to reflect Plan numbers and "Complete" status, but this is a documentation hygiene issue, not a functional gap.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | No TBD/FIXME/XXX/TODO markers; no placeholder returns; no hardcoded empty data flows |

### Human Verification Required

#### 1. Manifest Schema Validation — `claude plugin validate .`

**Test:** From the repo root, run `claude plugin validate .`
**Expected:** Exit 0 with 0 errors. The only expected output is at most the informational advisory "CLAUDE.md at the plugin root is not loaded as project context" (exit code 0, not a schema error).
**Why human:** Requires the `claude` CLI binary (`claude-code` package) which is not available in the verification environment. The JSON structure has been confirmed valid by inspection and the 10-01-SUMMARY.md reported exit 0, 0 errors.

#### 2. Manifest Schema Validation — `claude plugin validate .claude-plugin/plugin.json`

**Test:** From the repo root, run `claude plugin validate .claude-plugin/plugin.json`
**Expected:** Exit 0 with 0 errors (same advisory warning permitted).
**Why human:** Same constraint as above. Both manifest files pass `jq empty` and all structural requirements verified by grep — human confirmation of the `claude` CLI validator output is the only remaining gap.

### Gaps Summary

No functional gaps. All must-haves verified. The two human verification items are schema validation checks that require the `claude` CLI binary (available in CI but not in this offline verification context). The codebase evidence strongly supports both checks passing: the manifests have the exact structure documented in 10-01-SUMMARY.md as producing exit 0.

---

_Verified: 2026-05-25_
_Verifier: Claude (gsd-verifier)_
