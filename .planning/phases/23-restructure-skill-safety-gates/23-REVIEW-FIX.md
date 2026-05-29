---
phase: 23-restructure-skill-safety-gates
fixed_at: 2026-05-29T00:00:00Z
review_path: .planning/phases/23-restructure-skill-safety-gates/23-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 7
skipped: 1
status: partial
---

# Phase 23: Code Review Fix Report

**Fixed at:** 2026-05-29T00:00:00Z
**Source review:** .planning/phases/23-restructure-skill-safety-gates/23-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (1 critical, 3 warning, 4 info)
- Fixed: 7 (CR-01, WR-01, WR-02, WR-03, IN-01, IN-02, IN-04)
- Accepted-no-code-change: 1 (IN-03)
- Test suite: **429 / 0** (baseline was 427 / 0; +2 from the new CR-01 regression assertions)

## Fixed Issues

### CR-01: approve.sh applies `op: archive` steps during non-archive bucket approval

**Files modified:** `templates/skills/restructure/gates/approve.sh`, `tests/run.sh`
**Commit:** 9f92ea6
**Applied fix:** Added `select(.op != "archive")` (and `select(.status == "proposed")`)
to the bucket step-collector jq so an `op: archive` step can NEVER be applied during a
per-class non-archive bucket approval. Archive ops remain the sole responsibility of the
archive-last pass (SKILL.md step 6), which routes each candidate through
`gates/decision-scan.sh` for the individual-vs-bulk confirm (D-11/D-15). Added a Wave 0
regression in the Phase 23 block of `tests/run.sh` with two assertions: after approving
the `reference-doc` bucket, (1) step-2 (`op: archive`) stays `status: proposed` and
(2) `docs/OLD.md` is not moved into a `.conjure-archive-*` dir. **Verified the regression
FAILS against the pre-fix approve.sh** (PASS 427 / FAIL 2) and PASSES after the fix.

### WR-01: SKILL.md false claim — `CONJURE_ADOPT_STEP_JSON` "not forwarded / stdin only"

**Files modified:** `templates/skills/restructure/SKILL.md`
**Commit:** 10e49f4
**Applied fix:** Chose option (a) from the review — corrected the doc to state the truth
(confirmed against `adopt.sh:~423`: the env var is inherited by the child and read at
HIGHER priority than stdin). The "hard rule" and "forbidden actions" sections now instruct
the skill to register the op via stdin AND `unset CONJURE_ADOPT_STEP_JSON` if it might be
set, so the intended stdin payload is never shadowed. SKILL.md stays at 121 lines (≤200).

### WR-02: `CONJURE_FORCE_INTERACTIVE=1` bypasses the non-TTY no-auto-approve guard

**Files modified:** `templates/skills/restructure/gates/approve.sh`, `templates/skills/restructure/SKILL.md`
**Commit:** 10e49f4
**Applied fix:** ACCEPTED the behavior (it mirrors the established `resolve.sh:34` /
`adopt.sh:808` test hatch — consistency with the codebase convention) and hardened the
docs only: strengthened the inline comment in `approve.sh` to mark it TEST-ONLY and added a
forbidden-action in SKILL.md ("NEVER set or inherit `CONJURE_FORCE_INTERACTIVE`"). No
behavior change, so the Wave 0 non-TTY exit-2 test stays green.

### WR-03: verify-invariants substring match is granularity- and polarity-blind

**Files modified:** `templates/skills/restructure/gates/verify-invariants.sh`, `templates/skills/restructure/SKILL.md`
**Commit:** 07b0930
**Applied fix:** Took the documentation path only (per the review's "skip the code change
if it risks the green fixtures" guidance). Added a KNOWN-LIMITATION comment in the helper
(substring + polarity blindness; LLM proposer is primary, this gate is the deterministic
backstop — RESEARCH CR-1 residual MEDIUM accepted) and SKILL.md step 2 guidance to confirm
distinctive multi-word tokens. **Negation-detection was deliberately NOT added**: the
shipped canonical token `do not delete` embeds its own negation, and `with-invariant.md`
contains "do not use @import", so a `do not <token>` rejection would false-block the green
`with-invariant` / `reflowed-invariant` fixtures. No code-behavior change → fixtures stay
green.

### IN-01: init-project.sh uses `exit 1` (convention is `exit 2`)

**Files modified:** `scripts/init-project.sh`
**Commit:** bdfd2de
**Applied fix:** Changed the usage-error branch from `exit 1` to `exit 2` (project-wide
"never exit 1" convention).

### IN-02: approve.sh `[a]pprove` swallows per-step apply failures silently

**Files modified:** `templates/skills/restructure/gates/approve.sh`
**Commit:** bdfd2de
**Applied fix:** Added a `failed` counter and surfaced it in BOTH the on-screen line and
the durable RESTRUCTURE summary (`applied N step(s), M failed`). Kept it to a single
summary line per bucket so the D-09 one-line-per-bucket contract (and the existing
bulk-summary test) is preserved.

### IN-04: check.sh `grep -qF` added-file detection is an unanchored substring match

**Files modified:** `scripts/check.sh`
**Commit:** bdfd2de
**Applied fix:** Changed `grep -qF "$rel"` to `grep -qxF "$rel"` (whole-line match).
Confirmed the manifest is written as bare relative paths one-per-line (check.sh lines
54/60), so whole-line anchoring is exactly correct and eliminates the substring
false-negative the new nested skill-resource registrations made more likely.

## Skipped / Accepted-without-code-change Issues

### IN-03: approve.sh leaks temp files if `--apply-step` aborts the process

**File:** `templates/skills/restructure/gates/approve.sh:128-150`
**Reason:** ACCEPTED (not fixed). The clean fix (single `mktemp -d` + one EXIT trap)
would refactor the per-bucket temp-file + fd-redirect (`exec 3<` / `exec 4<`) logic that
the CR-01 fix and the green Wave 2 tests depend on. That exceeds the "trivial and
zero-risk" bar set for Info findings in this pass, so it is recorded for a future
hardening pass rather than risking the gate's working fd discipline. The leak is bounded
(two `mktemp` files per interrupted approval) and the temp files live in `$TMPDIR`.
**Original issue:** `paths_tmp` / `steps_tmp` are removed at line ~165 but have no `trap`
cleanup, so an interruption between creation and `rm -f` leaks them.

## Disposition Summary

| Finding | Severity | Disposition | Commit |
| --- | --- | --- | --- |
| CR-01 | Critical | fixed (+ regression test) | 9f92ea6 |
| WR-01 | Warning | fixed (doc corrected) | 10e49f4 |
| WR-02 | Warning | accepted + docs hardened | 10e49f4 |
| WR-03 | Warning | fixed (doc-only, per guidance) | 07b0930 |
| IN-01 | Info | fixed | bdfd2de |
| IN-02 | Info | fixed | bdfd2de |
| IN-03 | Info | accepted (no code change) | — |
| IN-04 | Info | fixed | bdfd2de |

**Constraint check:** every changed `.sh` passes
`shellcheck -S error -e SC2164,SC2044,SC2034,SC2155`; SKILL.md is 121 lines (≤200);
no `exit 1` introduced; `bash tests/run.sh` → **PASS 429 / FAIL 0** including the new
CR-01 regression.

---

_Fixed: 2026-05-29T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
