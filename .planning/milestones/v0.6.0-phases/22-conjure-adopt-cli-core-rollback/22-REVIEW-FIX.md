---
phase: 22-conjure-adopt-cli-core-rollback
fixed_at: 2026-05-29T00:00:00Z
review_path: .planning/phases/22-conjure-adopt-cli-core-rollback/22-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
test_suite: "PASS 401 / FAIL 0 (baseline 394/0; +7 new assertions)"
---

# Phase 22: Code Review Fix Report

**Fixed at:** 2026-05-29T00:00:00Z
**Source review:** .planning/phases/22-conjure-adopt-cli-core-rollback/22-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (CR-01, CR-02, WR-01, WR-02, WR-03, WR-04, WR-05, IN-03)
- Fixed: 8
- Skipped: 0
- Final test suite: `bash tests/run.sh` → PASS 401 / FAIL 0 (baseline was 394/0; +7 new assertions all green)
- shellcheck `-S error -e SC2164,SC2044,SC2034,SC2155` clean on every changed file
  (scripts/adopt.sh, lib/mutate.sh, tests/run.sh)

## Fixed Issues

### CR-01: `--apply-step` write op strips the trailing newline from staged content

**Files modified:** `lib/mutate.sh`, `scripts/adopt.sh`
**Commit:** fcc42a6
**Applied fix:** Added a `mutate_write_file <dest> <src>` chokepoint to `lib/mutate.sh`
(byte-exact `cp`, DRY_RUN-aware, counter-incrementing) — chosen over a raw `cp` so the
mutation still routes through `lib/mutate.sh` per the project routing invariant. Replaced
`mutate_write "$dest_abs" "$(cat "$abs_src")"` (lossy command substitution that strips the
trailing newline) with `mutate_write_file "$dest_abs" "$abs_src"`. The dest now byte-matches
the staged source and the recorded `mutated[].after` sha is the hash of the correct file.
Verified: a 52-byte staging file now round-trips to a 52-byte dest (was 51), and recorded
after-sha == on-disk sha.

### CR-02: `extract` op archives the new staging source instead of the old destination

**Files modified:** `scripts/adopt.sh`
**Commit:** fcc42a6
**Applied fix:** Refactored `apply_archive_op` to take the source-to-archive explicitly as
`$1` (no longer reads the outer `$src`). The `extract` case now archives the OLD dest
(`apply_archive_op "$dest"`, guarded on the dest existing as a file) BEFORE `apply_write_op`
overwrites it; the staging source is never archived. Verified: OLD dest content lands in
`.conjure-archive-*/` (sha matches old), NEW content lands at dest (sha matches staging),
and the staging file survives (write copies, never moves).

### WR-01: `--apply-step` mutates the destination before recording state (crash-durability gap)

**Files modified:** `scripts/adopt.sh`
**Commit:** fcc42a6
**Applied fix:** In `apply_write_op`, record intent BEFORE the mutation: for an overwrite,
append the `mutated[]` entry with a `"pending"` after-hash first, then finalize it with a
new `state_set_last_mutated_after` helper after the write completes; for a new file, append
to `created[]` before the write. This mirrors the forward pipeline's started→mutate→completed
ordering so a kill -9 between the write and the state record is recoverable.
**Note:** logic-adjacent ordering change — covered by the strengthened CR-01 after-sha
assertion and the full rollback round-trip test (sha256 zero-diff), both green.

### WR-02: `--resume` re-runs the dirty-tree gate without re-propagating `--force` (recovery deadlock)

**Files modified:** `scripts/adopt.sh`
**Commit:** 7042f30
**Applied fix:** Gated the `precondition_git` call in `run_pipeline` on
`[ "${CONJURE_ADOPT_REUSE_SNAPSHOT:-0}" = "1" ]` — on resume (which sets that flag) the
dirty-tree gate is skipped with a `[resume]` note, since the snapshot already captured the
tree and scaffold has since added untracked files. Verified: a forced run that is then
resumed without `--force` on a still-dirty tree now returns 0 (previously exit 2 / deadlock).

### WR-03: rollback's whole-tree restore truncates the durable audit log (SAFE-07 / D-04)

**Files modified:** `scripts/adopt.sh`
**Commit:** c24cadb
**Applied fix:** In `rollback_path`, copy the live `RESTRUCTURE-LOG.md` aside (mktemp, like
`created_list`/`mutated_list`) before `snapshot_rollback`, and restore it over the stale
snapshot copy after the whole-tree restore (cleaned up on the failure path too). The
subsequent `log_step ROLLBACK` then appends to the full trail. Verified: post-rollback log
reads `[SNAPSHOT] [INVENTORY] [SCAFFOLD] [AUDIT] [ROLLBACK]` with exactly one ROLLBACK entry
(was truncated to `[SNAPSHOT] [ROLLBACK]`).

### WR-04: `--apply-step` accepts a `dest` anywhere under the target, including `.git/` and backups

**Files modified:** `scripts/adopt.sh`
**Commit:** fcc42a6
**Applied fix:** Added a protected-dir denylist (case match, exit 2) after `resolve_under`
in `apply_write_op`, rejecting dest paths under `.git/`, `.conjure-adopt-backups/`,
`.conjure-adopt-state/`, and `.conjure-archive-*`. This also guards the extract write half
(extract routes through `apply_write_op`). Verified: write targeting `.git/hooks/pre-commit`,
`.conjure-adopt-backups/x`, and `.conjure-adopt-state/state.json` each exit 2 with no file
created.

### WR-05: `update_manifest` does not validate the `op` field against the allowlist

**Files modified:** `scripts/adopt.sh`
**Commit:** 601642c
**Applied fix:** Extended the inbound `jq -e` validation predicate in `update_manifest` to
also require `.op == "write" or .op == "archive" or .op == "extract"`. Verified: a valid
`archive` step appends (rc 0); `{"op":"delete"}` and `{}` are rejected with exit 2 and never
persisted to `restructure_steps[]`.

### IN-03: `extract` op is entirely untested (paired with CR-02) + CR-01 test strengthening

**Files modified:** `tests/run.sh`
**Commit:** 2c8e7a9
**Applied fix:** Added an isolated `extract` test (own sub-target, inline manifest step)
asserting: (a) OLD dest content lands in `.conjure-archive-*/`; (b) NEW staging content
lands at dest (byte-match); (a-neg) the archive holds OLD, not NEW, content; (c) the staging
source survives; and the step is marked `applied`. Also strengthened the CR-01 write-op
assertion to require the dest byte-matches the staged source (`cmp -s`) and that the recorded
`mutated[].after` sha equals the on-disk dest sha — so the trailing-newline corruption can no
longer regress undetected. Suite went 394 → 401 pass, 0 fail.

## Out-of-Scope / Not Fixed (per fix_scope directive)

- **IN-04** (`cli/conjure` failure paths use `return 1` vs the exit-2 convention): explicitly
  out of scope — pre-existing code untouched by Phase 22.
- **IN-01** (`update_manifest` `cat`s stdin with no TTY guard): optional hardening, skipped
  (not trivial-zero-risk relative to scope; left for a future pass).
- **IN-02** (`manifest_write_atomic` no pre-existence check): optional hardening, skipped
  (not currently reachable; both callers already guard `[ -f "$MANIFEST_PATH" ]`).

---

_Fixed: 2026-05-29T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
