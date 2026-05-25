---
phase: 01-pre-flight-cross-platform-hooks
verified: 2026-05-24T20:00:00Z
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
---

# Phase 01: Pre-flight & Cross-Platform Hooks Verification Report

**Phase Goal:** Pre-flight & Cross-Platform Hooks — extract preflight into standalone script with OS detection, wire as subcommand and audit gate, fix bash→node hook wiring for Windows compatibility
**Verified:** 2026-05-24T20:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

#### Plan 01-01 (SAFE-04) — Preflight Extraction

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running `conjure preflight` exits 0 when node and git are present and exits 1 when node is missing | VERIFIED | `cli/conjure preflight` exits 0 on dev machine (live run confirmed). Test suite assertion "correctly blocks when node missing" passes (PATH-strip test). |
| 2 | Running `conjure init` blocks with a non-zero exit if node is missing | VERIFIED | `cli/conjure` line 68: `cmd_preflight || return 1` inside `cmd_init()`, unchanged from pre-phase wiring; `cmd_preflight()` now delegates to `scripts/preflight.sh` which exits 1 on required-dep failure. |
| 3 | Running `conjure audit` invokes preflight first; missing deps cause audit to abort before running audit-setup.sh | VERIFIED | `cli/conjure` lines 110-113: `cmd_audit()` body reads `cmd_preflight || return 1` as first executable line, then `bash "$CONJURE_HOME/scripts/audit-setup.sh"`. |
| 4 | Each missing required dep prints a copy-pasteable, OS-detected install line (brew/apt/winget) to stdout | VERIFIED | `scripts/preflight.sh` `_fixup()` function covers all {node,git,jq,rg,shellcheck} × {macos,linux,wsl,windows-gitbash} combinations. Live run on macOS shows "brew install shellcheck" for missing optional dep. Test assertion "fix-it output contains brew (macOS)" passes. |
| 5 | Optional missing deps (jq, rg, shellcheck) produce a warning and exit 0 from preflight | VERIFIED | `scripts/preflight.sh` lines 114-121: optional loop prints "⚠ $dep not found (optional — some features degraded)" without setting REQUIRED_FAILED; script exits 0. Shellcheck absent on dev machine — live run confirms exit 0. Test assertion "exits 0 with shellcheck absent (optional)" passes. |
| 6 | scripts/preflight.sh can be invoked standalone from tests/run.sh without any CLI environment | VERIFIED | Script contains no `$CONJURE_HOME` references in executable code, no sourced variables. `tests/run.sh` calls `bash scripts/preflight.sh` directly (no CLI wrapper). Self-contained confirmed by grep. |

#### Plan 01-02 (SAFE-03) — Node Hook Wiring

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | A harness scaffolded by conjure init wires hooks via `node .claude/hooks/*.mjs` — hooks fire on native Windows | VERIFIED | `templates/settings.json.tmpl` contains 5 `node .claude/hooks/*.mjs` command strings and 0 `bash .claude/hooks/` strings. `scripts/init-project.sh` copies from `templates/hooks-nodejs/*.mjs`. |
| 8 | templates/settings.json.tmpl contains no `bash .claude/hooks/` command strings | VERIFIED | `grep -c 'bash .claude/hooks/' templates/settings.json.tmpl` returns 0. Template lint test "no bash hook commands" passes. |
| 9 | templates/settings.json.tmpl contains all five node hook commands with correct relative paths | VERIFIED | `grep -c 'node .claude/hooks/' templates/settings.json.tmpl` returns 5. All five hooks listed: post-edit-format.mjs, pre-bash-block-destructive.mjs, pre-commit-quality-gate.mjs, stop-compound-engineering.mjs, session-start-context.mjs. `jq empty` validates JSON. PreToolUse[Bash] has 2 hooks confirmed via `jq '.hooks.PreToolUse[0].hooks | length'` = 2. |
| 10 | scripts/audit-setup.sh checks for .mjs hook file existence, not .sh executable bit | VERIFIED | `audit-setup.sh` line 102: `find .claude/hooks -maxdepth 1 -name '*.mjs'`; line 99: `if [ -f "$hook" ]`. No `name '*.sh'` or `-x` executable-bit check remaining. No "chmod" reference in file. |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/preflight.sh` | Self-contained dep checker with OS detection, required/optional split, fix-it lines, exits 1 on required failure | VERIFIED | Exists, executable (`test -x` passes), 131 lines of substantive logic. Contains `_detect_os()`, `_fixup()`, required/optional loops, `set -uo pipefail` (not `-e`), bash 3.2+ compatible (no associative arrays). No `$CONJURE_HOME` dependency. |
| `cli/conjure` | `cmd_preflight()` stub delegating to scripts/preflight.sh; preflight in dispatch and usage(); `cmd_audit()` calls cmd_preflight first | VERIFIED | `cmd_preflight()` is a 3-line stub (`bash "$CONJURE_HOME/scripts/preflight.sh"`). `preflight)` case in dispatch at line 191. `conjure preflight` in `usage()` output at line 40. `cmd_audit()` calls `cmd_preflight || return 1` as first executable line. |
| `tests/run.sh` | Preflight test section (4 assertions); Template lint section (4 assertions) | VERIFIED | "Preflight script" section at line 105 with 4 assertions (smoke, block-on-required, fix-it grep, optional-missing). "Template lint" section at line 162 with 4 assertions. Full suite: 121 pass, 0 fail. |
| `templates/settings.json.tmpl` | 5 node .mjs hook commands; no bash commands; valid JSON | VERIFIED | 5 node commands, 0 bash commands, valid JSON (`jq empty` exits 0). PreToolUse[Bash] has 2 hooks. |
| `scripts/init-project.sh` | Hook copy loop sourcing templates/hooks-nodejs/*.mjs; no chmod | VERIFIED | Line 46: `for hook in "$KIT"/templates/hooks-nodejs/*.mjs`. No `chmod` in hook copy block. Idempotency guard `[ ! -f ".claude/hooks/$name" ]` preserved. |
| `scripts/audit-setup.sh` | Hook check for .mjs file existence, not .sh executable bit | VERIFIED | `find .claude/hooks -maxdepth 1 -name '*.mjs'` with `[ -f "$hook" ]` check. Old `*.sh`/`-x` check fully replaced. |

### Key Link Verification

#### Plan 01-01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `cli/conjure:cmd_preflight` | `scripts/preflight.sh` | `bash "$CONJURE_HOME/scripts/preflight.sh"` | WIRED | Confirmed at line 172 of cli/conjure |
| `cli/conjure:cmd_init` | `cmd_preflight` | `cmd_preflight || return 1` | WIRED | Line 68 — unchanged from pre-phase, propagates non-zero from preflight.sh |
| `cli/conjure:cmd_audit` | `cmd_preflight` | `cmd_preflight || return 1` (first executable line) | WIRED | Lines 110-113 — `cmd_audit()` body: `local target`, `cmd_preflight || return 1`, then `bash audit-setup.sh` |
| `tests/run.sh` | `scripts/preflight.sh` | `bash scripts/preflight.sh` (no CLI env) | WIRED | Lines 108, 123, 130, 151 — called directly without CLI wrapper |

#### Plan 01-02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/init-project.sh` hook copy loop | `templates/hooks-nodejs/*.mjs` | `for hook in "$KIT"/templates/hooks-nodejs/*.mjs` | WIRED | Line 46 — iterates all 5 .mjs files |
| `templates/settings.json.tmpl` | `.claude/hooks/*.mjs` | `"command": "node .claude/hooks/foo.mjs"` | WIRED | 5 node commands, all using relative paths |
| `scripts/audit-setup.sh` hook check | `.claude/hooks/*.mjs` | `find .claude/hooks -maxdepth 1 -name '*.mjs'` | WIRED | Line 102 — finds .mjs files, checks existence with `-f` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| SAFE-04 | 01-01 | Pre-flight reports each missing dep with OS-detected fix-it and never auto-installs | SATISFIED | `scripts/preflight.sh` with `_fixup()` covers brew/apt/winget per OS. No exec calls to package managers — only `printf` strings. All 4 SAFE-04 test assertions pass. REQUIREMENTS.md marks `[x] SAFE-04 Complete`. |
| SAFE-03 | 01-02 | Generated hook wiring runs on native Windows via `node .mjs` instead of `bash .sh` | SATISFIED | `templates/settings.json.tmpl` has 0 bash hooks, 5 node hooks. `init-project.sh` copies from `hooks-nodejs/*.mjs` with no chmod. `audit-setup.sh` checks `.mjs` existence. 4 template lint regression assertions in `tests/run.sh`. REQUIREMENTS.md marks `[x] SAFE-03 Complete`. |

No orphaned requirements found. REQUIREMENTS.md traceability table maps exactly SAFE-03 and SAFE-04 to Phase 1.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | None detected |

Debt marker scan (TBD, FIXME, XXX) across all 6 modified files: zero hits.
Warning marker scan (TODO, HACK, PLACEHOLDER): zero hits in implementation files.
Stub indicator scan (return null/{}): zero hits.
No auto-install exec calls in `scripts/preflight.sh` — only `printf` strings.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `scripts/preflight.sh` exits 0 when node and git present | `bash scripts/preflight.sh; echo "EXIT:$?"` | EXIT:0, shows "✓ node", "✓ git" | PASS |
| `conjure preflight` dispatches correctly | `cli/conjure preflight; echo "EXIT:$?"` | EXIT:0, full preflight output | PASS |
| `conjure help` lists preflight subcommand | `cli/conjure help \| grep preflight` | "  conjure preflight" | PASS |
| Full test suite | `bash tests/run.sh` | PASS: 121  FAIL: 0 | PASS |
| `templates/settings.json.tmpl` is valid JSON | `jq empty templates/settings.json.tmpl` | exit 0 | PASS |
| settings.json.tmpl has 5 node hooks | `grep -c 'node .claude/hooks/'` | 5 | PASS |
| settings.json.tmpl has 0 bash hooks | `grep -c 'bash .claude/hooks/'` | 0 | PASS |
| PreToolUse[Bash] has 2 hooks | `jq '.hooks.PreToolUse[0].hooks \| length'` | 2 | PASS |

### Probe Execution

No probe scripts declared in PLAN files. No `scripts/*/tests/probe-*.sh` found for this phase. Step 7c: SKIPPED (no probes declared).

### Human Verification Required

None. All must-haves are mechanically verifiable and confirmed by live execution. No visual UI, real-time behavior, or external service integration to assess.

### Gaps Summary

No gaps. All 10 must-have truths verified. Both requirement IDs (SAFE-03, SAFE-04) are fully satisfied with implementation evidence. All four task commits (cd812d6, 18e6364, 151fee8, 7a53eb9) confirmed in git. Full test suite exits 0 with 121 assertions passing.

---

_Verified: 2026-05-24T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
