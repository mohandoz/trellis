---
phase: 22-conjure-adopt-cli-core-rollback
plan: 03
subsystem: api
tags: [bash, cli, adopt, rollback, snapshot, recovery, jq, op-executor, sha256, path-traversal, skill-seam]

# Dependency graph
requires:
  - phase: 22-conjure-adopt-cli-core-rollback (plan 01)
    provides: "Phase 22 graceful-red test block (rollback/recovery/apply-step/update-manifest assertions) + the _adopt-restructure-steps synthetic manifest fixture"
  - phase: 22-conjure-adopt-cli-core-rollback (plan 02)
    provides: "scripts/adopt.sh forward pipeline + .conjure-adopt-state schema (snapshot_path/created[]/mutated[]) + state_record/sha_of helpers + mode-dispatch skeleton with the four stubs this plan fills"
  - phase: 21-foundation-libs-inventory
    provides: "lib/snapshot.sh (snapshot_rollback), lib/mutate.sh (mutate_rm/mutate_write/mutate_archive chokepoint), lib/log.sh (log_step), lib/inventory.sh"
provides:
  - "rollback_path (D-01): 3-step full-restore + delete-created + sha256-verify yielding Phase 24 zero-diff, with the SAFE-06/D-15 filesystem-not-git warning at rollback time"
  - "recovery_prompt (D-12/13/14): TTY [r]/[c]/[s] loop from /dev/tty (no default) + resume_pipeline that reuses the snapshot (no second backup, CR-2)"
  - "apply_step / update_manifest op-executor (D-05/06/07/08): the Phase 23 skill seam — skill proposes via --update-manifest, CLI applies via --apply-step through the lib/mutate.sh chokepoint, with op-allowlist + staging-path + traversal validation"
affects: [23 (restructure skill drives --apply-step/--update-manifest), 24 (Argus sha256-identical zero-diff after --rollback)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Capture-before-restore: read created[]/mutated[] into temp files BEFORE snapshot_rollback, because the snapshot carries a stale pre-scaffold state.json that the whole-tree restore would clobber"
    - "Snapshot-aware empty-dir prune on rollback: bottom-up rmdir of directories absent from the snapshot (rmdir is a no-op on non-empty dirs) — removes scaffold-created dirs while preserving every original dir, yielding true zero-diff"
    - "resolve_under <base> <candidate>: path-containment guard that rejects '..'/absolute-escape WITHOUT requiring the path to exist (apply-step src/dest validation)"
    - "Snapshot reuse on resume: CONJURE_ADOPT_REUSE_SNAPSHOT re-enters run_pipeline reading snapshot_path back from durable state instead of re-snapshotting the already-mutated tree"

key-files:
  created: []
  modified:
    - scripts/adopt.sh
    - tests/run.sh

key-decisions:
  - "Capture created[]/mutated[] BEFORE snapshot_rollback (the snapshot's stale state.json has an empty created[] that the restore would write over the live one)"
  - "Strip the leaked .snapshot-meta.json from the target root after restore, and prune snapshot-absent empty dirs, so the post-rollback tree is byte-identical to pre-adopt (D-03)"
  - "apply-step write src is TARGET-relative per the D-07 manifest convention (.conjure-adopt-state/staging/<file>), resolved under the target then asserted to live under the staging dir"
  - "archive op routes through a fresh timestamped .conjure-archive-<ts>/ root so the diff/inventory .conjure-archive-* exclusion holds"
  - "resume reuses the existing log + state rather than re-initializing (log_init replaces the file, state_init resets created[]) — D-12 continue, not restart"

patterns-established:
  - "rollback_path 3-step (D-01): capture → snapshot_rollback → rm-meta → mutate_rm created[] → prune snapshot-absent empty dirs → sha256-verify mutated[] → log [ROLLBACK] → drop only the state dir"
  - "manifest_write_atomic <jq-filter>: atomic temp+mv jq update of adopt-manifest.json (Pitfall 2) reused by --update-manifest append + --apply-step status:applied"
  - "Op-executor validation chain: op-type allowlist {write,archive,extract} → required-fields {id,op,status} → resolve_under containment → exit 2 with no partial mutation (T-22-09/10/11)"

requirements-completed: [SAFE-02, SAFE-05, SAFE-06, SAFE-07]

# Metrics
duration: 40min
completed: 2026-05-29
---

# Phase 22 Plan 03: conjure adopt rollback + recovery + op-executor Summary

**Filled the four Wave 2 mode-dispatch stubs in `scripts/adopt.sh`: the D-01 3-step rollback (snapshot restore → delete created[] → sha256-verify) that yields Phase 24 zero-diff, the [r]/[c]/[s] partial-run recovery prompt + `--resume` snapshot-reuse, and the `--apply-step`/`--update-manifest` op-executor (the Phase 23 skill seam) with op-allowlist + staging-path + traversal validation.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-05-29T21:00Z (approx)
- **Completed:** 2026-05-29
- **Tasks:** 2
- **Files modified:** 2 (scripts/adopt.sh, tests/run.sh)

## Accomplishments

- **rollback_path (D-01, SAFE-02):** captures `created[]`/`mutated[]` from `state.json` BEFORE `snapshot_rollback` (the snapshot carries a stale pre-scaffold `state.json` whose empty `created[]` would otherwise clobber the live one during the whole-tree restore), runs the whole-tree restore, strips the leaked `.snapshot-meta.json`, `mutate_rm`s every `created[]` path, prunes scaffold-created empty dirs absent from the snapshot, sha256-verifies every `mutated[]` path against its recorded before-hash, logs `[ROLLBACK]`, and deletes ONLY `.conjure-adopt-state` (D-04 keeps the snapshot/archive/log). Yields the Phase 24 sha256-identical zero-diff (D-03 exclusions) and surfaces the SAFE-06/D-15 "restores from the filesystem snapshot, NOT git" warning at rollback time.
- **recovery_prompt (D-12/13/14, SAFE-05):** the interactive `[r]ollback / [c]ontinue / [s]tart-fresh` loop reading from `/dev/tty` with NO default — unknown/empty input re-prompts (D-14). The non-TTY `exit 2` + "last completed: <step>" + recovery-flag list already lived in the Plan 02 dispatch; this plan added the TTY prompt body and the `resume_pipeline`/`--start-fresh` handlers it dispatches to.
- **resume_pipeline (`--resume` / `[c]ontinue`, D-12):** re-enters `run_pipeline` with `CONJURE_ADOPT_REUSE_SNAPSHOT=1`, reading `snapshot_path` back from durable state and SKIPPING `snapshot_guarded` so no second backup dir is created (CR-2); preserves the existing `RESTRUCTURE-LOG.md` + `state.json` rather than re-initializing them.
- **update_manifest (D-06):** reads a proposed op as JSON from stdin (or `CONJURE_ADOPT_STEP_JSON`), `jq`-validates required fields `{id, op, status}` (malformed → exit 2, never executed — T-22-11), appends to `restructure_steps[]` via injection-safe `--argjson` + atomic temp+mv. The inbound half of the Phase 23 skill seam.
- **apply_step (D-05/07/08):** reads op `#id`, enforces the op-type allowlist `{write, archive, extract}`, dispatches through the `lib/mutate.sh` chokepoint (RESTR-02), logs `RESTRUCTURE`, and marks `status: applied` atomically. `write` resolves the D-07 target-relative `src` under the target then requires it to live under `.conjure-adopt-state/staging/` (rejecting `..`/escape — T-22-09/10) and records `created[]`/`mutated[]` sha256 for rollback durability; `archive` resolves to an absolute traversal-free path under the target and routes to `mutate_archive` into a timestamped `.conjure-archive-<ts>/`; `extract` composes write+archive (D-08). Every validation failure `exit 2` with no partial mutation.

## Task Commits

Each task was committed atomically:

1. **Task 1: rollback_path + recovery prompt + --resume/--start-fresh (D-01/D-12/13/14)** — `0884eb5` (feat)
2. **Task 2: --apply-step / --update-manifest op-executor (D-05/06/07/08)** — `94ed371` (feat)

**Plan metadata:** _(this docs commit)_

## Files Created/Modified

- `scripts/adopt.sh` (modified) — filled `rollback_path`, `recovery_prompt`, `resume_pipeline`, `apply_step`, `update_manifest`; added `manifest_write_atomic` + `resolve_under` helpers; wired `--resume` to `resume_pipeline` in the mode dispatch and taught `run_pipeline`'s snapshot/log/state steps to reuse-not-recreate on resume.
- `tests/run.sh` (modified) — Rule 1 test-bug fix: moved the rollback zero-diff hash record out of the pristine comparison copy (see Deviations).

## Decisions Made

- **Capture-before-restore for rollback** — the snapshot is taken at the "snapshot" step (before scaffold), so its embedded `.conjure-adopt-state/state.json` has an empty `created[]`. `snapshot_rollback`'s whole-tree `cp -a snapshot/. target/` reverts the live `state.json` to that stale copy, so `created[]`/`mutated[]` MUST be read into temp files before the restore or the delete-created + verify loops read the wrong (emptied) arrays. Verified empirically before writing the code.
- **Two extra post-restore cleanups for true zero-diff** — (1) `rm -f "$TARGET/.snapshot-meta.json"` (the snapshot dir's root meta file leaks into the target via `cp -a snapshot/.`); (2) bottom-up `rmdir` of directories absent from the snapshot (scaffold-created dirs like `.claude/hooks`, `.claude/docs` left empty after `rm -f` of their `created[]` files). `rmdir` is a no-op on non-empty dirs, so this never deletes original content. Both were confirmed necessary by simulating the rollback against the brownfield fixture.
- **D-07 `src` semantics** — the manifest `src` (`.conjure-adopt-state/staging/<file>`) is TARGET-relative, so `write` resolves it under the target and then asserts containment under the staging dir (not anchored directly under staging, which would double the prefix).
- **`extract` boundary** — composed as `write` (dest from staging src) + `archive` (src), reusing the single `src` field for both halves. Phase 22 (D-08) only tests `write` + `archive` directly; the composition primitive is in place for Phase 23 to refine if a distinct old-path field is introduced. Noted under Known Stubs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rollback zero-diff assertion wrote its hash record INTO the compared tree**
- **Found during:** Task 1 (running the Phase 22 rollback section)
- **Issue:** The Plan 01 (Wave 0) rollback test set `P22_RB_HASHES="$P22_RB_PRE/.p22-hashes"` — i.e. it wrote the sha256 record file INTO the pristine pre-adopt copy that the zero-diff `diff -r "$P22_RB_PRE" "$P22_RB_TARGET"` later compares. So `.p22-hashes` was always "Only in PRE" and the zero-diff assertion could NEVER pass once the real rollback logic was correct (in the graceful-red baseline it failed for a different reason — `COMPOUND-CANDIDATES.md` — masking this latent bug). Same class of latent Wave 0 assertion bug as the Plan 02 self-copy deviation.
- **Fix:** Moved the hash record to a `mktemp` file outside both compared trees and extended the section's EXIT trap to clean it up.
- **Files modified:** `tests/run.sh`
- **Verification:** `adopt.sh rollback: diff -r pre-adopt vs post-rollback empty (excl. conjure dirs, D-03)` now passes; the production rollback path produces a genuinely empty diff.
- **Committed in:** `0884eb5` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug, in the Wave 0 test assertion — not production code)
**Impact on plan:** The fix corrects a Wave 0 assertion that could never pass; it does not alter any production behavior or expand scope. The production `rollback_path` was written to satisfy the assertion's true intent (byte-identical post-rollback tree).

## Issues Encountered

- The initial `apply_step` write path anchored `src` directly under the staging dir, producing the doubled path `.conjure-adopt-state/staging/.conjure-adopt-state/staging/CLAUDE.md` (the manifest `src` is target-relative, not staging-relative). Resolved by resolving `src` under the target and then asserting staging containment — confirmed against the synthetic fixture and the traversal/allowlist negative cases.

## Known Stubs

None that block this plan's goal. One design boundary worth flagging for Phase 23:

- `apply_step`'s `extract` op composes `write` + `archive` using the single `src` field for both halves. Phase 22 (D-08) ships + tests `write` and `archive` directly; if Phase 23's real restructure skill needs `extract` to write a *new* file from staging while archiving a *different* old path, it should add a distinct old-path field to the op and the dispatch will need a small extension. No Phase 22 assertion depends on `extract`.

## Verification

- `bash tests/run.sh`: **PASS 394 / FAIL 0** (Plan 02 baseline was PASS 387 / FAIL 7 — the 7 Wave 2 reds all turned green; zero non-Phase-22 regressions). Full suite exits 0.
- All Phase 22 sub-sections green: dry-run, live, dirty-tree, **rollback (4/4 incl. zero-diff)**, state+log, git-init harness, **SIGKILL recovery (4/4)**, **apply-step/update-manifest (5/5)**, self-copy regression.
- `shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 scripts/adopt.sh cli/conjure` (the CI quality gate) → clean. `scripts/adopt.sh` is also clean at warning severity (0 warnings; only the intentional info-level SC2016 jq single-quote filters remain, matching `lib/inventory.sh`).
- `grep -v '^#' scripts/adopt.sh | grep -c 'exit 1'` → 0 (project convention: hard failures use exit 2).
- Manual smoke (beyond the suite): apply-step `write`, `archive`, and `extract` all execute and mark `status: applied`; the four negative cases (unsupported op `delete`, `src` traversal `../../../etc/passwd`, `dest` escape `../outside.md`, `src` outside staging) all `exit 2` with no mutation (CLAUDE.md unchanged, no out-of-target file created — T-22-09/10/11 confirmed).

## Threat Flags

None — no security surface introduced beyond the plan's `<threat_model>` (T-22-09 through T-22-14). All mitigate-disposition threats are implemented: path-traversal validation (`resolve_under` + `mutate_archive` backstop), op-type allowlist + required-field check + `--argjson` injection-safety, `created[]`-scoped `mutate_rm` + `mutated[]` sha256 verify, `log_step ROLLBACK`/`RESTRUCTURE` audit trail, and non-TTY exit-2 (never auto-mutate).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Phase 23 (restructure skill):** the `--apply-step`/`--update-manifest` executor + the `.conjure-adopt-state/staging/<file>` (D-07) contract are working and tested against the synthetic fixture, exactly as the ROADMAP requires Phase 23 to depend on. The skill writes proposed ops via `--update-manifest` (stdin or `CONJURE_ADOPT_STEP_JSON`) and applies them via `--apply-step <id>`; every mutation routes through `lib/mutate.sh` (RESTR-02 chokepoint preserved). See the `extract` design boundary under Known Stubs if a distinct old-path field is needed.
- **Phase 24 (Argus zero-diff):** `conjure adopt --rollback` produces a byte-identical (`diff -r`, excluding `.conjure-adopt-backups`/`.conjure-archive-*`/`RESTRUCTURE-LOG.md`/`adopt-manifest.json`/`.conjure-adopt-state` per D-03) pre-adopt-vs-post-rollback tree, with per-file sha256 == recorded before-hash. The Phase 22 smoke version of the zero-diff test is green; Phase 24 can build the full Argus fixture on this guarantee.

## Self-Check: PASSED

- FOUND: `scripts/adopt.sh`
- FOUND: `.planning/phases/22-conjure-adopt-cli-core-rollback/22-03-SUMMARY.md`
- FOUND commits: `0884eb5`, `94ed371`
- TRACKED modifications: `scripts/adopt.sh`, `tests/run.sh`

---
*Phase: 22-conjure-adopt-cli-core-rollback*
*Completed: 2026-05-29*
