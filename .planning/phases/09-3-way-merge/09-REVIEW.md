---
phase: 09-3-way-merge
reviewed: 2026-05-25T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - .github/workflows/ci.yml
  - cli/conjure
  - lib/merge.sh
  - scripts/audit-setup.sh
  - tests/run.sh
findings:
  critical: 3
  warning: 5
  info: 2
  total: 10
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-05-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

This review covers the phase-09 3-way merge implementation: the new `lib/merge.sh` library, updates to `cli/conjure` (`cmd_init` snapshot writing + `cmd_update --apply` merge logic), the audit conflict-marker check added to `scripts/audit-setup.sh`, the 3-way merge test block added to `tests/run.sh`, and the CI shellcheck scope fix in `.github/workflows/ci.yml`.

The core merge logic (`merge_file_3way`, `write_merge_sidecar`, `merge_user_files`) is structurally sound. The critical findings are: a snapshot corruption bug on re-init (directory double-nesting via `cp -r`), silent content mutation via `mutate_write`'s unconditional trailing newline, and a missing error guard on the pre-merge backup `cp -R` that can proceed into destructive operations after a silent backup failure. Three warnings cover: unquoted variable word-splitting in the conflict-files loop, `cd` failures silently ignored in `audit-setup.sh`, and the double run of `audit-setup.sh` in the CI `audit-on-fixture` job.

## Critical Issues

### CR-01: Snapshot directory double-nesting on `conjure init` re-run

**File:** `cli/conjure:90-95`
**Issue:** When `conjure init` is re-run against the same target at the same version, `snap_dir` already exists because `mutate_mkdir` is a no-op on an existing directory. The subsequent `mutate_cp "$CONJURE_HOME/templates/skills" "$snap_dir/skills"` call invokes `cp -r src dest` where `dest` (`$snap_dir/skills`) already exists. The POSIX behaviour of `cp -r src dest` when `dest` exists is to copy `src` **into** `dest`, producing `$snap_dir/skills/skills/`. Subsequent 3-way merges then fail to find skill files at the expected path, silently skipping all merges (the `[ -f "$base" ]` guard evaluates false).

The same double-nesting applies to `agents` and `hooks`.

**Fix:** Guard the snapshot copy so it only runs when the snapshot directory is newly created, or use explicit sub-path copies that are idempotent:
```bash
# Option A: skip if snap_dir already fully populated
if [ ! -d "$snap_dir/skills" ]; then
  mutate_cp "$CONJURE_HOME/templates/skills"       "$snap_dir/skills"
  mutate_cp "$CONJURE_HOME/templates/agents"       "$snap_dir/agents"
  mutate_cp "$CONJURE_HOME/templates/hooks-nodejs" "$snap_dir/hooks"
fi

# Option B (safer): always write individual files, never whole directories
find "$CONJURE_HOME/templates/skills" -name SKILL.md | while IFS= read -r f; do
  rel="${f#$CONJURE_HOME/templates/}"
  mutate_mkdir "$snap_dir/$(dirname "$rel")"
  mutate_cp "$f" "$snap_dir/$rel"
done
```

---

### CR-02: `mutate_write` strips trailing blank lines from merged content

**File:** `lib/mutate.sh:62` (called from `lib/merge.sh:43`)
**Issue:** `mutate_write` writes content with `printf '%s\n' "$content"`. The `$content` argument is captured via `merged="$(git merge-file -p ...)"`. Command substitution in bash unconditionally strips **all** trailing newlines from the captured output. `printf '%s\n'` then adds exactly **one** newline back. This means any file that originally ended with two or more trailing newlines (common in Markdown to separate sections) is silently modified on every clean merge — the extra blank lines at EOF are destroyed. On the next `conjure update`, the base snapshot won't match the installed file, causing spurious conflicts or unnecessary re-merges.

**Fix:** Use `printf '%s' "$content"` (no trailing newline) and let the file content preserve whatever line ending was produced by `git merge-file -p`. Since `git merge-file` itself always terminates output with a newline when dealing with text files, this is safe:
```bash
# In lib/mutate.sh mutate_write():
if [ "$mode" = "--append" ]; then
  printf '%s' "$content" >> "$dest"
else
  printf '%s' "$content" > "$dest"
fi
```

---

### CR-03: Backup `cp -R` is unguarded — failed backup allows destructive merge to proceed

**File:** `cli/conjure:204`
**Issue:** The pre-merge backup is done with a bare `cp -R "$target/.claude" "$backup"`. If this fails (disk full, permission error), the command exits non-zero but execution continues because `set -uo pipefail` without `set -e` does not abort on a simple command failure. The merge then proceeds and mutates `.claude/` without any backup, violating the project's backup-before-mutate safety constraint.

```bash
# Current — silent failure allowed:
cp -R "$target/.claude" "$backup"

# After the unguarded cp -R, the destructive merge begins.
```

**Fix:** Abort if the backup fails:
```bash
cp -R "$target/.claude" "$backup" \
  || { echo "✗ Backup failed — aborting merge to protect your files."; return 1; }
```

---

## Warnings

### WR-01: Unquoted `$CONJURE_MERGE_CONFLICT_FILES` causes word-splitting on paths with spaces

**File:** `cli/conjure:227`
**Issue:** `for sf in $CONJURE_MERGE_CONFLICT_FILES` expands without quotes. If the project path contains spaces (e.g. `/Users/Jane Doe/my project/.claude`), sidecar paths will contain spaces and the loop will split them into multiple tokens, printing partial paths rather than the full sidecar filenames.

**Fix:**
```bash
# Replace the space-delimited string with newline-delimited and use while-read:
printf '%s\n' "$CONJURE_MERGE_CONFLICT_FILES" | while IFS= read -r sf; do
  [ -z "$sf" ] && continue
  echo "    $sf"
done
```
Alternatively, accumulate sidecar paths in a newline-delimited variable and iterate with `while IFS= read -r`.

---

### WR-02: `cd "$TARGET"` in `audit-setup.sh` silently continues on failure

**File:** `scripts/audit-setup.sh:9`
**Issue:** The script uses `set -uo pipefail` but **not** `set -e`. A bare `cd "$TARGET"` without an error guard does not abort the script if `$TARGET` does not exist — it fails silently and all subsequent checks run against the wrong directory (wherever the script was invoked from). This means `audit-setup.sh /nonexistent` audits the CWD and exits 0 or 1, never reporting the invalid target.

The CI suppresses SC2164 (`-e SC2164`) globally, which hides this risk from shellcheck.

**Fix:**
```bash
cd "$TARGET" || { echo "✗ Cannot cd to target: $TARGET"; exit 2; }
```

---

### WR-03: CI `audit-on-fixture` job runs `audit-setup.sh` twice — first run wasted

**File:** `.github/workflows/ci.yml:52-55`
**Issue:** Lines 52-53 run `audit-setup.sh` and discard all output (`|| true` with no capture). Lines 54-55 immediately run it a second time to capture the log and check for `PASS:`. The first invocation produces no useful signal and doubles the job's runtime for this step.

**Fix:** Remove the first invocation and consolidate:
```yaml
- name: Audit fixture
  run: |
    bash "$GITHUB_WORKSPACE/scripts/audit-setup.sh" /tmp/fixture > /tmp/audit.log 2>&1 || true
    grep -q "PASS:" /tmp/audit.log
```

---

### WR-04: `merge_user_files` tempfile not cleaned up on early return via `_rc -eq 2` in CLAUDE.md block

**File:** `lib/merge.sh:98-102`
**Issue:** The CLAUDE.md merge block (lines 98-102) returns 2 immediately when `merge_file_3way` fails with a git error. At this point no tempfile has been created yet for skills/agents/hooks, so there is no leak there. However, unlike the three `while` loops which explicitly `rm -f` their tempfiles before returning 2, the CLAUDE.md block has no tempfile to clean — this is actually fine. The warning is about the asymmetry in error paths being confusing and easy to break on future edits: the three loops all follow the pattern `rm -f "$list"; return 2` but the CLAUDE.md block just does `return 2`. A future developer adding a tempfile to the CLAUDE.md block might miss the cleanup.

**Fix:** Add a comment clarifying why the CLAUDE.md early-return needs no cleanup:
```bash
# No tempfile to clean here — CLAUDE.md is a single-file check.
if [ "$_rc" -eq 2 ]; then return 2; fi
```

---

### WR-05: `RETIRE_TMP` tempfile created but never written to — dead `mktemp`

**File:** `scripts/audit-setup.sh:234`
**Issue:** `RETIRE_TMP=$(mktemp)` allocates a tempfile and registers it for cleanup in the EXIT trap (line 236), but `RETIRE_TMP` is never written to anywhere in the retire-list block. The file is created and immediately cleaned up without purpose. This is dead code that wastes a syscall and creates unnecessary complexity in the trap chain.

**Fix:** Remove the `RETIRE_TMP` tempfile entirely:
```bash
# Delete lines 234-236; the trap at line 236 already correctly handles COST_TMP.
# Change line 236 to:
trap 'rm -f "${COST_TMP:-}"' EXIT
```

---

## Info

### IN-01: `lib/merge.sh` has no shebang and no `set` options — sourcing context dependency undocumented

**File:** `lib/merge.sh:1-5`
**Issue:** The file header documents that it must be sourced with `lib/mutate.sh` already loaded and `DRY_RUN` set. However it does not document the required shell options (`set -uo pipefail`) that callers must have active for correct error propagation. If someone sources `merge.sh` in a script without `set -uo pipefail`, command failures inside `merge_user_files` (e.g. a failing `find`) will be silently swallowed.

**Fix:** Add to the header comment:
```bash
# Caller must have 'set -uo pipefail' active — this file inherits shell options from caller.
```

---

### IN-02: `tests/run.sh` FM test temp dirs not registered in EXIT traps — potential leaks on abort

**File:** `tests/run.sh:338,352,365`
**Issue:** The three `FM_DIR` test blocks each create a `mktemp -d` and clean up inline with `rm -rf "$FM_DIR"` at the end of the block. If the script is interrupted (SIGINT) or aborted by `set -uo pipefail` on an unexpected pipe failure between the `mktemp` and the `rm -rf`, the temp dir leaks for the OS session. The dry-run section (line 189) and sandbox tests correctly register and clear EXIT traps; the FM tests do not follow this pattern.

**Fix:** Wrap each FM block in a trap:
```bash
FM_DIR="$(mktemp -d)"
trap 'rm -rf "$FM_DIR"' EXIT
# ... test body ...
rm -rf "$FM_DIR"
trap - EXIT
```

---

_Reviewed: 2026-05-25T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
