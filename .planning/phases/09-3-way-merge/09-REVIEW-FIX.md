---
phase: 09-3-way-merge
fixed_at: 2026-05-25T00:00:00Z
review_path: .planning/phases/09-3-way-merge/09-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 09: Code Review Fix Report

**Fixed at:** 2026-05-25T00:00:00Z
**Source review:** .planning/phases/09-3-way-merge/09-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (3 Critical + 5 Warning; Info excluded by fix_scope)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: Snapshot directory double-nesting on `conjure init` re-run

**Files modified:** `cli/conjure`
**Commit:** af77a0b
**Applied fix:** Added `[ ! -d "$snap_dir/skills" ]`, `[ ! -d "$snap_dir/agents" ]`, and `[ ! -d "$snap_dir/hooks" ]` guards around each `mutate_cp` directory call so that on re-init the existing snapshot subdirectories are not re-copied into themselves (which would produce `skills/skills/` etc. via POSIX `cp -r src dest` behaviour when `dest` already exists).

---

### CR-02: `mutate_write` strips trailing blank lines from merged content

**Files modified:** `lib/mutate.sh`
**Commit:** 8e0f259
**Applied fix:** Changed both `printf '%s\n' "$content"` calls in `mutate_write` to `printf '%s' "$content"` (no forced trailing newline). Command substitution already strips trailing newlines from the captured merge output; adding one back silently destroyed extra blank lines at EOF on every clean merge.

---

### CR-03: Backup `cp -R` is unguarded — failed backup allows destructive merge to proceed

**Files modified:** `cli/conjure`
**Commit:** 968a263
**Applied fix:** Added `|| { echo "✗ Backup failed — aborting merge to protect your files."; return 1; }` after the `cp -R "$target/.claude" "$backup"` line in `cmd_update`, preventing the merge from proceeding if the pre-merge backup fails.

---

### WR-01: Unquoted `$CONJURE_MERGE_CONFLICT_FILES` causes word-splitting on paths with spaces

**Files modified:** `cli/conjure`
**Commit:** 178d8da
**Applied fix:** Replaced `for sf in $CONJURE_MERGE_CONFLICT_FILES; do` with `printf '%s\n' "$CONJURE_MERGE_CONFLICT_FILES" | while IFS= read -r sf; do` (with empty-line guard) to avoid word-splitting on paths that contain spaces.

---

### WR-02: `cd "$TARGET"` in `audit-setup.sh` silently continues on failure

**Files modified:** `scripts/audit-setup.sh`
**Commit:** ed263c8
**Applied fix:** Changed bare `cd "$TARGET"` to `cd "$TARGET" || { echo "✗ Cannot cd to target: $TARGET"; exit 2; }` so the script aborts with a clear error if the target directory does not exist rather than auditing the wrong directory.

---

### WR-03: CI `audit-on-fixture` job runs `audit-setup.sh` twice — first run wasted

**Files modified:** `.github/workflows/ci.yml`
**Commit:** 4598a40
**Applied fix:** Removed the first discarded invocation (`|| true` with no output capture). Kept only the second invocation that writes to `/tmp/audit.log` and checks for `PASS:`, eliminating the redundant run that doubled job time for the step.

---

### WR-04: Asymmetric early-return in `merge_user_files` CLAUDE.md block — no cleanup comment

**Files modified:** `lib/merge.sh`
**Commit:** eeddb30
**Applied fix:** Added `# No tempfile to clean here — CLAUDE.md is a single-file check.` comment immediately before `if [ "$_rc" -eq 2 ]; then return 2; fi` in the CLAUDE.md block, making the asymmetry with the three `while` loops (which do `rm -f "$list"; return 2`) intentional and documented.

---

### WR-05: `RETIRE_TMP` tempfile created but never written to — dead `mktemp`

**Files modified:** `scripts/audit-setup.sh`
**Commit:** 35d7baa
**Applied fix:** Removed the `RETIRE_TMP=$(mktemp)` allocation and the comment above it. Updated the EXIT trap from `trap 'rm -f "${COST_TMP:-}" "${RETIRE_TMP:-}"' EXIT` to `trap 'rm -f "${COST_TMP:-}"' EXIT`, which correctly handles the case where `--retire-list` runs without `--cost` (COST_TMP unset, safe via `:-` expansion) while eliminating the dead tempfile.

---

_Fixed: 2026-05-25T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
