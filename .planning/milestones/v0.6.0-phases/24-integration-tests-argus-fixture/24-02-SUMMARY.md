---
phase: 24-integration-tests-argus-fixture
plan: 02
subsystem: testing
tags: [bash, e2e, adopt, rollback, sigkill, symlink, at-import, shellcheck, run-sh]

# Dependency graph
requires:
  - phase: 24-integration-tests-argus-fixture
    plan: 01
    provides: "tests/fixtures/_brownfield-argus/generate-argus.sh (500-file fixture: docs/linked.md symlink, with-import.md @import seed, 127-line CLAUDE.md) + scripts/adopt.sh report() 'nothing to scaffold' deviation"
  - phase: 22-adopt-pipeline
    provides: "scripts/adopt.sh live/dry-run/snapshot/inventory/scaffold/rollback/recovery pipeline + state.json .current_step + RESTRUCTURE-LOG.md [ROLLBACK] entry"
  - phase: 23-restructure-skill
    provides: "templates/skills/restructure/gates/audit-staged.sh (@import → exit 2)"
provides:
  - "tests/run.sh ▸ Phase 24 E2E block — 5 criterion sections (C1–C5) behind a P24_ARGUS_OK guard, proving the shipped Phases 21–23 pipeline at 500-file scale"
affects: [v0.6.0-milestone-audit, e2e-adopt, ci-matrix]

# Tech tracking
tech-stack:
  added: []  # zero new deps — find/wc/tr/jq/diff/date/grep + reused p22_sha only (CLAUDE.md dependencies:{} lock honored)
  patterns:
    - "Reuse the existing Phase 22 P22_ADOPT_SH + p22_sha helpers (in scope earlier in run.sh) — add only a parallel P24_ARGUS_GEN/P24_ARGUS_OK presence guard"
    - "Anti-flake relaunch loop (up to 3 attempts) around the SIGKILL launch+poll+kill: out-of-window kills (process finished OR step past inventory) clear state+backups and relaunch from a pristine cp -aR copy; only after 3 out-of-window attempts is a fail recorded"
    - "current_step poll (jq -r '.current_step') breaking on snapshot|inventory — more precise than the Phase 22 backups-dir-existence poll for the 'after snapshot, before scaffold' window"

key-files:
  created: []
  modified:
    - tests/run.sh

key-decisions:
  - "Reused P22_ADOPT_SH + p22_sha verbatim (not redefined) per the plan's read_first — Phase 24 adds only the P24_ARGUS_GEN/P24_ARGUS_OK guard and section-local P24_* vars"
  - "C4 anti-flake: wrapped launch+poll+kill in a 3-attempt relaunch loop keyed on the LAST OBSERVED current_step at kill time; in-window iff that step was snapshot or inventory — a timing slip retries rather than going false-RED (guards the inherent kill-window race)"
  - "Hash record (C2) and run1-after snapshot (C3) + PRE copies (C2/C4) all live in mktemp dirs/files OUTSIDE the diff'd trees (Pitfall 4 / the 22-03 Rule-1 lesson) — never written into a tree later diff'd"
  - "cp -aR (not cp -r) used for every PRE/snapshot copy to preserve the real ln -s symlink so the symlink-skip assertion (C5a) and the zero-diff comparisons (C2/C3/C4) are faithful"
  - "C4 interactive [r]/[c]/[s] prompt left manual-only (documented with a # NOTE:) — PTY-verified in Phases 22/23; only the non-TTY exit-2 + auto-rollback path is automated"

patterns-established:
  - "Per-criterion E2E section skeleton: mktemp sandbox + trap set → generate argus → run pipeline under env-var contract → assert observable signal → rm -rf + trap - EXIT, all behind a dual P22_ADOPT_OK && P24_ARGUS_OK presence guard for graceful RED"
  - "SIGKILL-window anti-flake relaunch loop for timing-race tests"

requirements-completed: []  # verification phase — no REQ-* IDs (gated by the 5 ROADMAP criteria)

# Metrics
duration: 8min
completed: 2026-05-29
---

# Phase 24 Plan 02: ▸ Phase 24 E2E Verification Block Summary

**The `▸ Phase 24` block in `tests/run.sh` — five criterion sections (C1–C5) that
drive the shipped `conjure adopt` + restructure-gate pipeline against the 500-file
`_brownfield-argus` fixture and assert all five v0.6.0 ROADMAP success criteria
end-to-end: <30s dry-run + zero writes, rollback zero-diff (per-file sha256 +
`diff -r`), idempotent re-run ("nothing to scaffold"), SIGKILL-after-snapshot
recovery (non-TTY exit 2 + auto-rollback zero-diff via a 3-attempt anti-flake
relaunch loop), and symlink-skip + @import pre-write block — taking the full suite
from PASS 429 to PASS 447, FAIL 0, shellcheck-clean.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-29T03:26:34Z
- **Completed:** 2026-05-29T03:34:50Z
- **Tasks:** 2
- **Files modified:** 1 (tests/run.sh; +304 lines across 2 commits)

## Accomplishments

- **C1 (criterion 1) — dry-run perf + zero writes:** a `DRY_RUN=1` adopt on the
  500-file argus fixture completes in a `date +%s` integer-second delta of **5s**
  (< the 30s ROADMAP ceiling, ~6x margin) and writes zero artifacts (no
  `adopt-manifest.json`, no `.conjure-adopt-state` under the non-git sandbox).
- **C2 (criterion 2) — rollback zero-diff:** a live adopt then
  `CONJURE_ADOPT_ROLLBACK=1 --rollback` restores every pre-adopt file to its
  recorded `p22_sha` sha256 (0 mismatches), logs `[ROLLBACK]` in
  `RESTRUCTURE-LOG.md`, and yields an empty `diff -r` vs the pristine PRE copy
  (with the 5 D-03 excludes).
- **C3 (criterion 3) — idempotent re-run:** a second adopt (state cleared between
  runs) reports `Scaffolded: 0 layer files`, `state.json .created|length == 0`,
  an empty `diff -r` between run1-after and run2-after, AND emits the literal
  `nothing to scaffold` (consuming the Plan 01 O-1 `report()` deviation).
- **C4 (criterion 4) — SIGKILL recovery after snapshot:** a backgrounded adopt is
  `kill -9`'d in the snapshot/inventory window (caught via a `current_step` poll
  inside a 3-attempt anti-flake relaunch loop); the non-TTY re-run exits 2 with a
  `last completed:` line and all three `--rollback`/`--resume`/`--start-fresh`
  flags; then `CONJURE_ADOPT_ROLLBACK=1 --rollback` restores cleanly (empty
  `diff -r` vs PRE). The interactive `[r]/[c]/[s]` prompt is documented manual-only.
- **C5 (criterion 5) — symlink skip + @import block:** `docs/linked.md` is absent
  from manifest `files[]` (inventory skipped the real `ln -s`), `audit-staged.sh`
  on a staged `@import` CLAUDE.md exits 2, and the target `CLAUDE.md` never gains
  an `^@` line.
- Full suite **PASS 447 / FAIL 0** (429 baseline + 18 new Phase 24 assertions, no
  regression); `bash -n` clean; `shellcheck -S error -e SC2164,SC2044,SC2034,SC2155`
  exits 0; `exit 1` count unchanged at the 15-line baseline (no `exit 1` introduced).

## Task Commits

Each task was committed atomically:

1. **Task 1: ▸ Phase 24 block foundation + C1 + C2 + C3** — `168e1ca` (test)
2. **Task 2: ▸ Phase 24 C4 + C5 + close block + no-regression gate** — `ffd70e8` (test)

**Plan metadata:** docs commit (see final commit).

## Files Created/Modified

- `tests/run.sh` (MODIFY) — inserted the `▸ Phase 24` block after `:3280` ("End
  Phase 23 test block") and before the gh-stub cleanup. Block contents:
  - Section banner + the `P24_ARGUS_GEN`/`P24_ARGUS_OK` presence guard (reuses the
    earlier-in-scope `P22_ADOPT_SH` + `p22_sha`).
  - 5 criterion sections (C1 dry-run/zero-write @ line 3301, C2 rollback @ 3338,
    C3 idempotent @ 3394, C4 SIGKILL @ 3445, C5 symlink/@import @ 3542), each
    behind a `P22_ADOPT_OK -eq 1 && P24_ARGUS_OK -eq 1` dual guard with a graceful
    RED fail message, each using a mktemp sandbox with set/reset EXIT-trap
    discipline.
  - "End Phase 24 test block" banner @ line 3583, before the gh-stub cleanup (3587)
    and the Summary (3592).

## Decisions Made

- **Reuse, don't redefine:** the plan's `read_first` notes `P22_ADOPT_SH` and
  `p22_sha` are defined earlier in the same script and in scope — Phase 24 calls
  them directly and adds only the parallel `P24_ARGUS_GEN`/`P24_ARGUS_OK` guard
  (avoids a duplicate-helper drift between the two blocks).
- **C4 kill-window precision (Pattern 3 over the Phase 22 looser poll):** the
  Phase 22 SIGKILL section polls on `.conjure-adopt-backups` dir existence; Phase
  24 instead polls `jq -r '.current_step'` and breaks on `snapshot|inventory`
  ("snapshot done, scaffold not yet"), per 24-RESEARCH Pitfall 3 (the pipeline
  order is snapshot → inventory → scaffold, so the window spans inventory).
- **C4 anti-flake relaunch loop:** because the in-window catch is an inherent
  timing race on a fast/loaded runner, the launch+poll+kill is wrapped in a
  3-attempt loop keyed on the last observed `current_step`; an out-of-window kill
  (process finished, or step already at scaffold/audit) clears
  `.conjure-adopt-state`/`.conjure-adopt-backups`, restores a pristine `cp -aR`
  copy, and relaunches — only after 3 out-of-window attempts is a fail recorded.
- **`cp -aR` everywhere a copy is made:** preserves the real `ln -s` symlink so the
  C5a symlink-skip assertion and the C2/C3/C4 zero-diff comparisons are faithful
  (a `cp -r` would dereference and change the tree shape).
- **Records/snapshots live OUTSIDE the diff'd trees:** the C2 hash file, the C3
  run1-after snapshot, and the C2/C4 PRE copies are all `mktemp` dirs/files
  outside the target — directly applying the Phase 22 22-03 Rule-1 lesson (never
  write a record file into a tree later `diff -r`'d, or it pollutes the zero-diff).

## Deviations from Plan

None — both tasks executed exactly as written. The plan's `read_first` already
specified reusing `p22_sha`; the implementation follows that. No auto-fixes (Rules
1–3) were needed: the baseline was PASS 429/0 before changes and PASS 447/0 after,
shellcheck-clean, `exit 1` count unchanged. The C4 anti-flake relaunch loop is the
plan's explicitly-mandated structure (the plan's `<action>` warns to wrap
launch+poll+kill in a 3-attempt loop), not an unplanned deviation.

## Issues Encountered

None. C1's dry-run measured 5s (well under the 30s ceiling, matching the research's
~6s observation). The C4 kill landed in-window on the first attempt
(`current_step=snapshot`), so the anti-flake relaunch loop was not needed this run
but remains in place to guard CI runner variance. No flakiness observed across the
two full-suite runs taken for Task 1 and Task 2.

## Threat Surface

No new attack surface — matches the plan's `<threat_model>` (T-24-02 accept,
T-24-SC accept). The block spawns and `kill -9`s its own background bash process
within a bounded `seq` poll (no blind sleep, no unbounded loop), `wait`s it, and
writes only into trap-cleaned `mktemp -d` sandboxes. Zero external packages, no
network, no auth, no crypto, no product-code change. The pipeline's own security
gates (path-traversal, op-allowlist, protected-dir) are exercised — not modified —
by these assertions (14/14 threats already closed in Phases 22/23). No threat flags
raised.

## Manual-Only Sub-Check (documented, per plan + 24-VALIDATION)

- **C4 interactive `[r]/[c]/[s]` recovery prompt via a real TTY** — not reliably
  CI-automatable (needs a PTY); already UAT'd in Phases 22/23. A `# NOTE:` in the
  C4 section documents this. The automated half (non-TTY exit 2 + the three
  recovery flags + the explicit `CONJURE_ADOPT_ROLLBACK=1` auto-rollback zero-diff)
  fully covers the automatable surface of criterion 4.

## User Setup Required

None — no external service configuration. The new block runs in the existing
`bash tests/run.sh` invocation that CI already executes on the OS matrix (no
`.github/workflows/ci.yml` change needed).

## Next Phase Readiness

- All five v0.6.0 ROADMAP success criteria for Phase 24 now have GREEN automated
  E2E assertions against the 500-file argus fixture. The phase deliverable is
  complete; `/gsd-verify-work` can confirm the full suite green + shellcheck-clean.
- This is the FINAL plan of Phase 24 (Wave 2) and the final phase of the v0.6.0
  "Safe Brownfield Adoption" milestone — the milestone is ready for its close-out
  audit.
- No blockers. The one known limitation (SIGKILL in the snapshot-flush window
  fails-closed) remains a tracked Deferred Item from Phase 22; it is out of scope
  here (this block kills strictly AFTER snapshot completes, in the
  snapshot/inventory window).

## Self-Check: PASSED

- FOUND: `tests/run.sh` (modified — 5 `▸ Phase 24` sections present)
- FOUND: `.planning/phases/24-integration-tests-argus-fixture/24-02-SUMMARY.md`
- FOUND: commit `168e1ca` (Task 1 — C1/C2/C3)
- FOUND: commit `ffd70e8` (Task 2 — C4/C5 + close)
- VERIFIED: `bash tests/run.sh` → PASS 447 / FAIL 0; `bash -n` clean; shellcheck rc 0; `exit 1` count == 15 (baseline)

---
*Phase: 24-integration-tests-argus-fixture*
*Completed: 2026-05-29*
