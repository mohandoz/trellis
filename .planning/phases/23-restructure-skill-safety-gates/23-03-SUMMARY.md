---
phase: 23-restructure-skill-safety-gates
plan: 03
subsystem: restructure-skill
tags: [bash, skill, approval-driver, dev-tty, scaffold, restructure, safety-gates, nyquist]

# Dependency graph
requires:
  - phase: 23-restructure-skill-safety-gates
    provides: "Wave 1 four gate helpers (verify-invariants/audit-staged/extract-invariants/decision-scan) the SKILL.md orchestrates + approve.sh drives; Wave 0 graceful-red scaffold/criterion-1/archive-last/non-TTY/bulk-summary assertions"
  - phase: 22-conjure-adopt-cli-core-rollback
    provides: "the adopt seam — conjure adopt --update-manifest (stdin) / --apply-step <id>; scripts/init-project.sh scaffold loop; lib/log.sh log_step; scripts/resolve.sh /dev/tty non-TTY exit-2 model"
provides:
  - "templates/skills/restructure/SKILL.md — the human-gated restructure runbook (orchestration prose, ≤200 lines, allowed-tools: [Read, Bash], RESTR-01/02)"
  - "templates/skills/restructure/gates/approve.sh — per-class /dev/tty approve/skip/edit driver, non-TTY exit-2 (D-12), one RESTRUCTURE summary line per bucket (D-09), no external editor on edit (O-3)"
  - "init-project.sh scaffolds restructure (whole dir incl. gates/) during conjure adopt + conjure init (D-16)"
affects: [restructure-skill, scripts/check.sh, conjure-adopt, conjure-init]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Verb-source selection: read the approval verb from /dev/tty in a real interactive session, from stdin when forced-interactive (CONJURE_FORCE_INTERACTIVE=1 / no /dev/tty) — survives CI/piped drives without crashing under set -u"
    - "Non-TTY guard FIRST (before arg interpretation) so any non-interactive drive (< /dev/null) exits 2 regardless of positional-arg shape (D-12)"
    - "Flexible positional args: $1-is-a-dir → target; $1-is-a-file → manifest — one driver satisfies both the plan's manifest-path AC and the test's target-dir drive"
    - "Skill-resource drift: check.sh registers EVERY kit file under an installable skill dir (SKILL.md + attached gates/*.sh), so whole-dir-copied helpers are not flagged as added drift and ARE integrity-checked"

key-files:
  created:
    - "templates/skills/restructure/SKILL.md"
    - "templates/skills/restructure/gates/approve.sh"
  modified:
    - "scripts/init-project.sh"
    - "scripts/check.sh"

key-decisions:
  - "approve.sh reads the verb from /dev/tty only when stdin is a genuine TTY; under CONJURE_FORCE_INTERACTIVE=1 (the test harness, and any context where /dev/tty is unavailable) it reads from stdin. A blind read < /dev/tty crashed with 'Device not configured' + an unbound-variable abort in the bulk-summary drive — the harness pipes the verbs over stdin, not /dev/tty."
  - "check.sh now enumerates the full contents of any installable skill dir into its drift manifest (Rule 3 fix): init-project.sh copies restructure/ whole-dir (mutate_cp cp -r), so its gates/*.sh landed in init'd harnesses but were absent from check.sh's SKILL.md-only manifest → flagged as 5 'added' files → drift → exit 1, breaking DRIFT-01/02 + AUTPR-01. The fix also upgrades check to verify skill-attached-resource integrity (a tampered gate helper is now detected as Modified)."
  - "Archive-last is encoded in SKILL.md prose ordering (op:write/op:extract documented before op:archive), satisfying the Wave 0 line-order assertion without any runtime ordering logic in the thin skill (D-01/D-15)."

patterns-established:
  - "Thin-skill chokepoint: SKILL.md is [Read, Bash]-only orchestration prose; every mutation crosses conjure adopt --apply-step; no Write/Edit on project files (RESTR-02)"
  - "One summary line per bucket even on EOF/no-response — the verb loop logs a skip-summary on read failure so a bucket always produces exactly one RESTRUCTURE log entry (D-09)"

requirements-completed: [RESTR-01, RESTR-02, RESTR-03]

# Metrics
duration: 9min
completed: 2026-05-29
---

# Phase 23 Plan 03: Restructure Skill + Approval Driver Summary

**The thin `[Read, Bash]` restructure SKILL.md (110 lines), the per-class `/dev/tty` approve/skip/edit approval driver (non-TTY → exit 2, one RESTRUCTURE summary line per bucket), and the one-token init-project.sh scaffold edit — flipping the last 4 Wave 0 graceful-reds green (scaffold/criterion-1, archive-last, non-TTY approval, bulk summary) and closing Phase 23 at 427 PASS / 0 FAIL.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-05-29 (Phase 23 Wave 2 execution session)
- **Completed:** 2026-05-29
- **Tasks:** 2
- **Files modified:** 2 created, 2 modified

## Accomplishments
- **approve.sh (per-class approval driver):** non-TTY guard FIRST (mirrors resolve.sh:34) → `exit 2` on `< /dev/null`, never auto-approves (D-12). Iterates the 6 NON-archive buckets `core skill agent planning-doc reference-doc unknown`, prints one `/dev/tty` prompt per non-empty bucket with a count + up to 5 sample paths, and runs an `approve`/`skip`/`edit` verb loop. `approve` applies each proposed step in the bucket via `conjure adopt --apply-step` (routes through lib/mutate.sh, RESTR-02) and logs ONE `RESTRUCTURE` summary line (D-09/SAFE-07); `skip` logs one summary line; `edit` signals the skill to re-draft + re-run GATE A/B with NO external editor (O-3) and re-prompts; empty/unknown re-prompts (no default, D-14). bash-3.2-safe (fd-3/fd-4 walks, no mapfile/assoc arrays), shellcheck-clean, zero `exit 1`.
- **init-project.sh (D-16 scaffold edit):** added `restructure` to the line-59 tooling-skills loop before `_anatomy`. `mutate_cp` (`cp -r`) copies the whole dir so `SKILL.md` + `gates/*.sh` all land. Since `adopt.sh` runs `init-project.sh existing`, the skill scaffolds during `conjure adopt` (criterion 1) — and also during `conjure init`.
- **SKILL.md (110 lines, orchestration prose only):** frontmatter `name`/`description` + `allowed-tools: [Read, Bash]` + belt-and-suspenders `disallowed-tools: [Write, Edit]`. Narrates the full read→extract-invariants→propose-via-stdin→GATE A+B→per-class approve→archive-LAST flow; inputs table, gate-catalog table, verb-semantics table, forbidden-actions list, cross-reference tail. Sequences `op:write`/`op:extract` before `op:archive` (D-15). No fenced bash loops (D-01).
- **Suite:** 427 PASS / 0 FAIL. All Phase 23 assertions green (4 gate helpers, scaffold/criterion-1, allowed-tools, ≤200-line cap, apply-step routing, group-by, archive-last, non-TTY exit-2, bulk summary). Zero pre-Phase-23 regression.

## Task Commits

Each task was committed atomically:

1. **Task 1: approve.sh per-class driver + init-project.sh scaffold edit** — `c1a498e` (feat)
2. **Task 2: SKILL.md + approve.sh verb-source fix + check.sh skill-resource drift fix** — `fabd5eb` (feat)

## Files Created/Modified
- `templates/skills/restructure/SKILL.md` — the human-gated restructure runbook (≤200 lines, `allowed-tools: [Read, Bash]`, orchestration prose only).
- `templates/skills/restructure/gates/approve.sh` — per-class `/dev/tty` approve/skip/edit driver; non-TTY exit-2; bulk summary log.
- `scripts/init-project.sh` — line-59 scaffold loop now installs `restructure` (whole dir incl. `gates/`).
- `scripts/check.sh` — drift manifest now registers every kit file under an installable skill dir (SKILL.md + attached resources), not just SKILL.md.

## Decisions Made
- **Verb-source selection (the load-bearing fix):** the first draft read the verb with `read -r ... < /dev/tty` unconditionally. The bulk-summary test drives `printf 'a\na\n' | CONJURE_FORCE_INTERACTIVE=1 bash approve.sh <target>` — `/dev/tty` is unavailable there, so the read failed with `Device not configured` and `set -u` aborted on the unbound `choice`. Fixed by selecting the source once: `/dev/tty` when `[ -t 0 ]` (a genuine interactive session), else stdin (where the harness/pipe feeds verbs). A `read_choice` helper returns non-zero on EOF so the loop breaks cleanly (logging a skip-summary) instead of crashing.
- **Flexible positional args:** the plan's AC drives `approve.sh <manifest-path>`, but the test drives `approve.sh <target-dir>`. The driver detects which: `$1` is a directory → target (manifest at `<target>/adopt-manifest.json`); `$1` is a file → manifest (target = `$2` or the manifest's dir). The non-TTY guard runs FIRST regardless, so both forms exit 2 on `< /dev/null`.
- **Seam invocation is PATH-independent:** `conjure` is not on `PATH` in the test env, so the driver invokes the seam as `bash "$CONJURE_HOME/cli/conjure" adopt --apply-step …`. The SKILL.md prose still writes the public `conjure adopt …` form a user would run.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] approve.sh crashed on a missing /dev/tty under the forced-interactive bulk drive**
- **Found during:** Task 2 full-suite verification (the bulk-summary assertion).
- **Issue:** reading the verb unconditionally from `/dev/tty` aborted (`Device not configured` + unbound-variable under `set -u`) when the harness forces interactive mode and pipes verbs over stdin — no `RESTRUCTURE` summary line was ever logged.
- **Fix:** read from `/dev/tty` only when stdin is a real TTY; otherwise read from stdin. Added a `read_choice` helper that breaks cleanly on EOF (logging a skip-summary). This was committed as part of Task 2 since both halves ship in approve.sh.
- **Files modified:** `templates/skills/restructure/gates/approve.sh`
- **Commit:** `fabd5eb`
- **Verification:** bulk drive now logs exactly one `RESTRUCTURE` line per bucket; non-TTY drive still exits 2.

**2. [Rule 3 - Blocking] check.sh flagged the scaffolded gates/*.sh as added drift**
- **Found during:** Task 2 full-suite verification (DRIFT-01/02 + AUTPR-01 went red).
- **Issue:** the Task 1 scaffold edit made `conjure init` install `restructure/` whole-dir (incl. 5 `gates/*.sh`). `check.sh`'s drift manifest registered only `.claude/skills/<name>/SKILL.md` per skill, so the 5 helper files were classified `added` → drift → `exit 1`. This deterministically broke the three zero-drift assertions (they `conjure init` a harness then assert `check` reports no drift).
- **Fix:** `check.sh` now enumerates every file the kit ships under each installable skill dir (find -type f, mapped back to `templates/skills/<rel>` for hashing). Whole-dir-copied resources are no longer spurious drift — and a tampered gate helper is now correctly reported as `Modified` (a security upgrade for skill-attached resources).
- **Files modified:** `scripts/check.sh`
- **Commit:** `fabd5eb`
- **Verification:** DRIFT-01/02 + AUTPR-01 restored to green; a modified `approve.sh` is reported `M`; full suite 427 PASS / 0 FAIL. shellcheck-clean.

## Issues Encountered
- The check.sh drift regression initially co-mingled with the same `fatal: not a git repository` noise the 23-02 SUMMARY flagged. Isolating DRIFT-01a (`conjure init` a temp dir, then `conjure check`) showed `Added (5): .claude/skills/restructure/gates/*.sh` deterministically — a real regression from the scaffold edit, not the chained-suite flakiness. Fixed at the source in check.sh.

## User Setup Required
None — no external service configuration. The driver is pure bash + `jq`/`mktemp`/`sed`; `dependencies: {}` stays empty.

## Manual UAT (criterion 2 — the ONE interactive item)
The interactive `approve/skip/edit` `/dev/tty` loop (criterion 2) is the documented manual/expect UAT — its automated half (non-TTY → exit 2) is green in the suite (D-12/RESTR-03). The live per-class prompt + the `edit` re-draft-and-re-run-gates cycle (O-3) require a real TTY and a human, and are NOT claimed as automated. Recommended UAT: run `conjure adopt` on a brownfield repo, reach the approval step, and exercise approve / skip / edit / empty-input across at least two buckets, confirming archive prompts come last and decision-vocabulary files escalate to individual confirmation.

## Next Phase Readiness
- **Phase 23 is complete** (Waves 0/1/2). The restructure skill is installed and operational: scaffolded into any target during `conjure adopt`/`conjure init` (criterion 1), declares the `[Read, Bash]` chokepoint (RESTR-02), narrates the human-gated propose→GATE A+B→per-class approve→archive-last flow over the shipped Phase 22 seam (RESTR-01), and enforces per-class grouped approval with non-TTY exit-2 + one bulk summary line (RESTR-03).
- No blockers. Suite at 427 PASS / 0 FAIL; zero pre-Phase-23 regression; `check` now integrity-verifies skill-attached resources.

## TDD Gate Compliance
This plan's tasks are not per-task `tdd="true"`; the RED gate shipped in Wave 0 (23-01) as the graceful-red scaffold/criterion-1/archive-last/non-TTY/bulk-summary assertions in `tests/run.sh`. This wave is the GREEN gate — both task commits are `feat(...)` commits that turn those reds green. This matches the established Phase 22/23 Wave 0→2 test-first precedent; no separate per-task `test(...)` RED commit is expected because the RED already shipped in Wave 0.

## Self-Check: PASSED

SKILL.md (110 lines, `allowed-tools: [Read, Bash]`), approve.sh (non-TTY exit-2, no `EDITOR`, zero `exit 1`), the init-project.sh scaffold edit, and the check.sh skill-resource fix all exist on disk; both task commits (`c1a498e`, `fabd5eb`) are present in git history. Full suite 427 PASS / 0 FAIL with every Phase 23 assertion green and DRIFT-01/02 + AUTPR-01 restored. shellcheck-clean at error severity across approve.sh / init-project.sh / check.sh; the only `exit 1` in scope is the pre-existing init-project.sh:17 usage guard (unchanged, out of scope). No project files written by the skill — every mutation routes through the conjure adopt chokepoint.

---
*Phase: 23-restructure-skill-safety-gates*
*Completed: 2026-05-29*
