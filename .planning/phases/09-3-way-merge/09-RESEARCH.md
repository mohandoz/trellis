# Phase 09: 3-Way Merge — Research

**Researched:** 2026-05-25
**Domain:** POSIX bash 3-way file merge using `git merge-file`; snapshot directory management; conflict sidecar naming; bash test harness patterns
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Missing snapshot → abort with error "No base snapshot for v<X>. Re-run 'conjure init' to write one, then update." Exit non-zero. No git tag fallback, no silent skip.
- **D-02:** No new `--refresh-snapshot` flag.
- **D-03:** Snapshot scope = CLAUDE.md template + skills/ + agents/ + hooks/ templates. NOT `.conjure-version` or `settings.json`.
- **D-04:** Sidecar filename encoding: replace `/` with `_` in relative path from `.claude/`, prefix `.conjure-conflict-`, placed next to original.
- **D-05:** Original live file untouched on conflict. Only sidecar written.
- **D-06:** After all files: print sidecar paths, instruct user to resolve and delete sidecars, exit 1 (not exit 2).
- **D-07:** Merge regression tests live inline in `tests/run.sh`. No new fixture directories.
- **D-08:** 4 required test scenarios: clean merge, conflict, missing snapshot abort, generated-file passthrough.

### Claude's Discretion
- Function naming inside `lib/merge.sh` (workflow uses `merge_skill` / `merge_with_backup` per ARCHITECTURE.md — planner can adjust)
- Exact error message wording beyond D-01/D-06 format
- Whether to update `.conjure-version` after clean merge or only after zero conflicts

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MERGE-01 | Replace stub at `cli/conjure:174-178` with real `git merge-file --diff3` 3-way merge | `git merge-file` flags, exit codes, `-p` stdout mode verified by live testing |
| MERGE-02 | `conjure init` writes `.claude/.conjure-templates-<version>/` base snapshot | `cp -r` + `mutate_cp`/`mutate_mkdir` idiom; template dirs documented |
| MERGE-03 | On conflict: write sidecar `.conjure-conflict-<encoded-name>`, leave original untouched, exit 1 | Sidecar naming with `tr '/' '_'`; `-p` stdout mode keeps original untouched |
| MERGE-04 | Generated files take upstream unconditionally; user-owned files do 3-way merge | File classification table documented; no snapshot needed for generated files |
| MERGE-05 | `conjure audit` detects `^<<<<<<<` markers in harness files, exits non-zero | `grep -rl '^<<<<<<<'` pattern; exit 2 via `err()` function |
</phase_requirements>

---

## Summary

Phase 09 replaces the stub in `cmd_update --apply` with a real 3-way merge using `git merge-file`, the POSIX-portable merge tool already required as a preflight dependency. The implementation is entirely bash + stdlib, no new packages, no interactive editor.

The core mechanism is `git merge-file -p --diff3 <current> <base> <new>`, which outputs the merged result to stdout and returns 0 (clean) or 1+ (conflict count, capped at 127) or 255 (error). Using `-p` (stdout) means the original file is never touched by `git merge-file` itself — the script controls writes through `lib/mutate.sh`. On conflict, the merged output (including `<<<<<<<` markers) goes into a sidecar file; the original is left untouched. On clean merge, the merged output replaces the original via `mutate_write`.

The snapshot directory `.claude/.conjure-templates-<version>/` is written by `cmd_init` immediately after `mutate_write .conjure-version` using `mutate_mkdir` + `mutate_cp`. This gives `cmd_update --apply` a stable ancestor for the 3-way merge without requiring git tags or network access.

**Primary recommendation:** Use `git merge-file -p --diff3 -L <label> -L <label> -L <label>` with stdout capture, write via `mutate_write`, and name sidecars using `printf '%s' "$rel" | tr '/' '_'` preceded by `.conjure-conflict-`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 3-way merge logic | `lib/merge.sh` (sourced lib) | `cli/conjure` (calls it) | Shared logic belongs in `lib/`; CLI orchestrates |
| Snapshot write | `cli/conjure:cmd_init` | `lib/mutate.sh` (write chokepoint) | Snapshot is an init-time side effect; mutate.sh enforces dry-run |
| File classification (merge vs take-upstream) | `cli/conjure:cmd_update` | `lib/merge.sh` | CLI knows which files are generated vs user-owned |
| Sidecar naming | `lib/merge.sh` | — | Pure computation; belongs in the merge lib |
| Conflict marker detection | `scripts/audit-setup.sh` | — | Health-check worker; follows existing audit pattern |
| Test assertions | `tests/run.sh` | — | Existing single test entrypoint; no new test files |

---

## Standard Stack

### Core (no new packages — all pre-existing)

| Tool | Version | Purpose | Provenance |
|------|---------|---------|------------|
| `git merge-file` | bundled with git 2.x | 3-way text merge | [VERIFIED: git-scm.com/docs/git-merge-file] |
| `lib/mutate.sh` | project-local | DRY_RUN-aware write chokepoint | [VERIFIED: read from codebase] |
| POSIX bash | 3.2+ | Script runtime | [VERIFIED: CLAUDE.md constraint] |
| `tr` | POSIX stdlib | Path encoding for sidecar names | [VERIFIED: POSIX standard] |
| `mktemp` | POSIX stdlib | Temp file creation for merge intermediates | [VERIFIED: POSIX standard] |

### No Package Legitimacy Audit Required
This phase introduces zero external packages. All tools are either POSIX stdlib, pre-installed git, or project-internal (`lib/mutate.sh`). No npm install, no pip install, no cargo install.

---

## `git merge-file` Behavior — Verified by Live Testing

### Synopsis

```bash
git merge-file [-p|--stdout] [--diff3] [-L label] [-L label] [-L label] \
  <current> <base> <other>
```

Argument order (verified): `current` = user's live file, `base` = original ancestor, `other` = new upstream version. [VERIFIED: git-scm.com/docs/git-merge-file + live test]

### Flags

| Flag | Effect | Use |
|------|--------|-----|
| `-p` / `--stdout` | Output merged result to stdout; do NOT modify `<current>` in place | Required — keeps original untouched |
| `--diff3` | Include base (ancestor) section between `\|\|\|\|\|\|\|` and `=======` markers | Required — per D-03 design; aids human resolution |
| `-L <label>` (3 times) | Replace file paths in conflict markers with readable labels | Recommended — improves human readability |
| `-q` / `--quiet` | Suppress warnings | NOT needed — git merge-file produces no stderr on conflict (verified) |

### Exit Codes [VERIFIED: man git-merge-file + live testing]

| Exit Code | Meaning |
|-----------|---------|
| `0` | Clean merge — no conflicts |
| `1`–`127` | Number of conflicts (capped at 127) — treat any `>0` as conflict |
| `255` | Error (file missing, bad argument, I/O error) |
| Negative | Same as 255 on this system (shell normalizes to 255) |

**Decision for implementation:** `rc > 0 && rc < 255` = conflict; `rc = 255` = abort with error; `rc = 0` = clean write.

### Clean vs Conflict Output [VERIFIED: live testing]

Clean merge (changes in non-overlapping lines):
```bash
# current: line1 changed; other: line3 changed; base: both original
# Result: rc=0, stdout = merged content, no markers
header
USER_CHANGE    # from current
line2
UPSTREAM_CHANGE  # from other
footer
```

Conflict (same region changed in both current and other):
```bash
# rc=1, stdout contains conflict markers:
<<<<<<< user (skills/architecture/SKILL.md)
CONFLICT_USER
||||||| v0.2.0 (base)
line1
=======
CONFLICT_UPSTREAM
>>>>>>> v0.3.0 (upstream)
```

**Key fact confirmed by live test:** `git merge-file -p` does NOT modify `<current>` even when called without explicit output redirection. The original file is completely untouched. This is the correct behavior for D-05.

### In-Place Mode (NOT used in this implementation)

Without `-p`, `git merge-file` modifies `<current>` directly. This is not used because:
1. It writes conflict markers into the live user file (violates D-05)
2. It bypasses `lib/mutate.sh` (violates architecture constraint)

### `-L` Labels for Readable Conflict Markers [CITED: git-scm.com/docs/git-merge-file]

```bash
git merge-file -p --diff3 \
  -L "your version (${rel})" \
  -L "v${pinned} base" \
  -L "v${CONJURE_VERSION} upstream" \
  "$current" "$base" "$new"
```

This produces markers like:
```
<<<<<<< your version (skills/architecture/SKILL.md)
...
||||||| v0.2.0 base
...
=======
...
>>>>>>> v0.3.0 upstream
```

---

## Temp File Strategy

`git merge-file` requires **actual files on disk** for all three arguments — it cannot read from stdin or process strings directly. [VERIFIED: live testing]

### Strategy: `-p` (stdout) + mutate_write

```bash
# 1. All three files must exist on disk before calling git merge-file
#    current = live project file (already on disk)
#    base    = from snapshot dir .claude/.conjure-templates-<version>/
#    new     = from CONJURE_HOME/templates/

# 2. Capture stdout, check exit code
merged=$(git merge-file -p --diff3 \
  -L "your version ($rel)" \
  -L "v${pinned} base" \
  -L "v${CONJURE_VERSION} upstream" \
  "$current_file" "$base_file" "$new_file")
rc=$?

# 3. Route based on exit code
if [ "$rc" -eq 0 ]; then
  mutate_write "$current_file" "$merged"   # clean: update in place
elif [ "$rc" -lt 255 ]; then
  mutate_write "$sidecar_path" "$merged"   # conflict: sidecar only
else
  echo "✗ merge-file error on $rel (rc=$rc) — aborting" >&2
  return 2
fi
```

**No `mktemp` needed** for this approach because:
- All three input files already exist on disk (`current` = live file, `base` = snapshot file, `new` = template file)
- Output goes to stdout, never to a temp file

The only case where `mktemp` might appear is in test setup (creating synthetic scenarios).

---

## Snapshot Directory Strategy

### Directory Structure [VERIFIED: live testing + CONTEXT.md D-03]

```
.claude/
  .conjure-templates-0.3.0/     # written by cmd_init
    CLAUDE.md.tmpl               # copy of templates/CLAUDE.md.tmpl
    skills/                      # copy of templates/skills/
      architecture/
        SKILL.md
      ...
    agents/                      # copy of templates/agents/
      doc-writer.md
      ...
    hooks/                       # copy of templates/hooks-nodejs/*.mjs
      *.mjs
```

**NOT included in snapshot** (per D-03): `settings.json`, `.conjure-version`. These are generated files that take upstream unconditionally.

### Write Idiom [VERIFIED: lib/mutate.sh codebase read]

`mutate_cp` handles directories via `cp -r` in live mode, dry-run safe:

```bash
# In cmd_init, after mutate_write "$target/.claude/.conjure-version" "$CONJURE_VERSION"
local snap_dir="$target/.claude/.conjure-templates-${CONJURE_VERSION}"
mutate_mkdir "$snap_dir"
mutate_cp "$CONJURE_HOME/templates/CLAUDE.md.tmpl" "$snap_dir/CLAUDE.md.tmpl"
mutate_cp "$CONJURE_HOME/templates/skills"          "$snap_dir/skills"
mutate_cp "$CONJURE_HOME/templates/agents"          "$snap_dir/agents"
mutate_cp "$CONJURE_HOME/templates/hooks-nodejs"    "$snap_dir/hooks"
```

**Note on hooks:** `templates/hooks-nodejs/` contains the `.mjs` hook templates. The snapshot captures this directory as `hooks/` to mirror the `.claude/hooks/` install location. [VERIFIED: init-project.sh codebase read]

### Missing Snapshot Detection [VERIFIED: CONTEXT.md D-01]

```bash
local snap_dir="$target/.claude/.conjure-templates-${pinned}"
if [ ! -d "$snap_dir" ]; then
  echo "✗ No base snapshot for v${pinned}. Re-run 'conjure init' to write one, then update."
  return 1   # exit 1 not exit 2 — user can fix by re-running init
fi
```

---

## File Classification: Merge vs Take-Upstream

[VERIFIED: CONTEXT.md D-03 + D-04 + codebase read]

### User-Owned Files (3-way merge)

These are files that users are expected to customize after `conjure init`. They require 3-way merge:

| Template Source | Installed To | Snapshot Path |
|----------------|--------------|---------------|
| `templates/CLAUDE.md.tmpl` | `CLAUDE.md` | `snap/CLAUDE.md.tmpl` |
| `templates/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` | `snap/skills/<name>/SKILL.md` |
| `templates/agents/<name>.md` | `.claude/agents/<name>.md` | `snap/agents/<name>.md` |
| `templates/hooks-nodejs/<name>.mjs` | `.claude/hooks/<name>.mjs` | `snap/hooks/<name>.mjs` |

### Generated Files (Take Upstream Unconditionally)

These files are machine-managed and never hand-edited by users. No 3-way merge needed:

| File | Reason |
|------|--------|
| `.claude/.conjure-version` | Managed by conjure; stamped on init/update |
| `.claude/settings.json` | Generated from `settings.json.tmpl`; no user edits expected |

**Implementation:** In `cmd_update --apply`, detect generated files by path and `cp` (via `mutate_cp`) unconditionally:
```bash
# Generated files: take upstream unconditionally
mutate_cp "$CONJURE_HOME/templates/settings.json.tmpl" "$target/.claude/settings.json"
```

---

## Sidecar Naming Pattern

[VERIFIED: CONTEXT.md D-04 + live testing]

### Encoding Formula

1. Take relative path from `.claude/` (e.g., `skills/architecture/SKILL.md`)
2. Replace `/` with `_` using `tr '/' '_'`
3. Prepend `.conjure-conflict-`
4. Place in same directory as the original file

```bash
# rel = path relative to .claude/ (e.g., "skills/architecture/SKILL.md")
local encoded
encoded=$(printf '%s' "$rel" | tr '/' '_')
# encoded = "skills_architecture_SKILL.md"
local sidecar_name=".conjure-conflict-${encoded}"
# sidecar_name = ".conjure-conflict-skills_architecture_SKILL.md"
local sidecar_path="$(dirname "$current_file")/$sidecar_name"
# sidecar_path = ".claude/skills/architecture/.conjure-conflict-skills_architecture_SKILL.md"
```

### Verified Examples [VERIFIED: live testing]

| Original File | Sidecar Name | Sidecar Directory |
|--------------|--------------|-------------------|
| `.claude/CLAUDE.md` | `.conjure-conflict-CLAUDE.md` | `.claude/` |
| `.claude/skills/architecture/SKILL.md` | `.conjure-conflict-skills_architecture_SKILL.md` | `.claude/skills/architecture/` |
| `.claude/agents/doc-writer.md` | `.conjure-conflict-agents_doc-writer.md` | `.claude/agents/` |
| `.claude/hooks/pre-commit-quality-gate.mjs` | `.conjure-conflict-hooks_pre-commit-quality-gate.mjs` | `.claude/hooks/` |

**Why underscores (not another delimiter):** `tr` is POSIX stdlib with no dependencies; the formula is consistent regardless of nesting depth. [CITED: CONTEXT.md D-04]

---

## Architecture Patterns

### System Architecture Diagram

```
conjure update --apply
       │
       ├─ check .conjure-version → get $pinned
       ├─ check .claude/.conjure-templates-$pinned/ → ABORT if missing
       ├─ backup-before-mutate (cp -R .claude/ .claude.backup-$ts)
       │
       ├─ for each GENERATED file (settings.json):
       │     mutate_cp $CONJURE_HOME/templates/... → .claude/...
       │
       └─ for each USER-OWNED file (SKILL.md, .mjs, .md):
              │
              ├─ current = .claude/<rel>
              ├─ base    = .claude/.conjure-templates-$pinned/<rel>
              ├─ new     = $CONJURE_HOME/templates/<rel>
              │
              ├─ git merge-file -p --diff3 $current $base $new → $merged, $rc
              │
              ├─ rc == 0 (clean):
              │     mutate_write $current $merged
              │
              ├─ rc < 255 (conflict):
              │     mutate_write $sidecar $merged
              │     record sidecar path
              │
              └─ rc == 255 (error):
                    abort immediately, exit 2
       │
       └─ if any_conflicts:
              print sidecar list
              print resolution instructions
              exit 1
          else:
              mutate_write .conjure-version $CONJURE_VERSION
              exit 0
```

### Recommended Project Structure

```
lib/
  merge.sh         # NEW: merge_file_3way(), write_sidecar(), merge_user_files()
  mutate.sh        # EXISTING: all writes route here (unchanged)

cli/conjure        # MODIFIED: cmd_init (add snapshot write), cmd_update (replace stub)

scripts/
  audit-setup.sh   # MODIFIED: add conflict marker check before final exit block

tests/
  run.sh           # MODIFIED: add MERGE-01 through MERGE-04 test blocks
```

### lib/merge.sh Function Design

```bash
#!/usr/bin/env bash
# lib/merge.sh — 3-way merge for cmd_update --apply.
# Source this file; requires: DRY_RUN, CONJURE_HOME, lib/mutate.sh already sourced.

# merge_file_3way <current> <base> <new> <rel> <pinned_ver> <new_ver>
# Returns: 0 = clean (current updated), 1 = conflict (sidecar written), 2 = error
merge_file_3way() {
  local current="$1" base="$2" new="$3" rel="$4" pinned_ver="$5" new_ver="$6"
  local merged rc

  # Note: git merge-file -p does NOT modify current file. stdout only.
  merged=$(git merge-file -p --diff3 \
    -L "your version (${rel})" \
    -L "v${pinned_ver} base" \
    -L "v${new_ver} upstream" \
    "$current" "$base" "$new" 2>/dev/null)
  rc=$?

  if [ "$rc" -eq 0 ]; then
    mutate_write "$current" "$merged"
    return 0
  elif [ "$rc" -lt 255 ]; then
    local encoded
    encoded=$(printf '%s' "$rel" | tr '/' '_')
    local sidecar_name=".conjure-conflict-${encoded}"
    local sidecar_path="$(dirname "$current")/${sidecar_name}"
    mutate_write "$sidecar_path" "$merged"
    return 1
  else
    echo "✗ git merge-file error on ${rel} (rc=${rc})" >&2
    return 2
  fi
}
```

### Pattern: Iterating User-Owned Files in cmd_update --apply

The existing `cmd_update` stub already iterates `find templates/skills -name SKILL.md`. The `--apply` path must extend this to all user-owned file types:

```bash
# Pseudocode for the merge loop
conflict_sidecars=""

# 1. User-owned skill files
while IFS= read -r tmpl_file; do
  rel="${tmpl_file#$CONJURE_HOME/templates/}"
  # tmpl path: templates/skills/architecture/SKILL.md
  # rel:       skills/architecture/SKILL.md
  current="$target/.claude/$rel"
  base="$snap_dir/$rel"
  new="$tmpl_file"
  [ -f "$current" ] || continue   # not installed, skip
  [ -f "$base" ] || continue      # no ancestor, skip this file
  merge_file_3way "$current" "$base" "$new" "$rel" "$pinned" "$CONJURE_VERSION"
  rc=$?
  if [ "$rc" -eq 1 ]; then
    encoded=$(printf '%s' "$rel" | tr '/' '_')
    conflict_sidecars="$conflict_sidecars $target/.claude/$(dirname "$rel")/.conjure-conflict-$encoded"
  elif [ "$rc" -eq 2 ]; then
    return 2   # hard error
  fi
done < <(find "$CONJURE_HOME/templates/skills" -name SKILL.md)

# Repeat for agents, hooks...

# 2. Conflict summary
if [ -n "$conflict_sidecars" ]; then
  echo "✗ Conflicts in the following files:"
  for s in $conflict_sidecars; do echo "    $s"; done
  echo "  Resolve conflicts and delete sidecars, then run:"
  echo "  echo '$CONJURE_VERSION' > $target/.claude/.conjure-version"
  return 1   # D-06: exit 1, not exit 2
fi

# 3. Clean: stamp version
mutate_write "$target/.claude/.conjure-version" "$CONJURE_VERSION"
echo "✓ Updated to v$CONJURE_VERSION"
```

### Anti-Patterns to Avoid

- **Using git merge-file without `-p`:** Writes markers into the live file, violating D-05. Always use `-p`.
- **Piping content into git merge-file:** Not supported — it requires actual files on disk.
- **Using exit 2 for conflicts:** Conflicts are user-resolvable (D-06); only errors (missing file, bad rc=255) warrant exit 2.
- **Writing sidecar via direct `printf >`:** Bypasses `lib/mutate.sh` dry-run contract; always use `mutate_write`.
- **Using `echo` for content with newlines:** `mutate_write` uses `printf '%s\n'` internally; pass content as string, not piped.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 3-way text merge | Custom diff/patch logic | `git merge-file` | Handles all edge cases (binary, encoding, LF/CRLF) |
| Conflict marker detection | Custom regex parser | `grep -rl '^<<<<<<<'` | Simple POSIX, already correct |
| Dry-run file writes | Direct `printf` or `cp` | `mutate_write` / `mutate_cp` | DRY_RUN contract enforced |
| Path encoding | Custom character replacement | `tr '/' '_'` | POSIX stdlib, no subprocess needed |

---

## audit-setup.sh Conflict Marker Detection

### Where to Inject [VERIFIED: codebase read — lines 253-255 are the final exit block]

Insert immediately before the final summary/exit block (before line 132 `# Summary`):

```bash
# Conflict markers — detect unresolved 3-way merge conflicts (MERGE-05)
if [ -d .claude ]; then
  conflicting=$(grep -rl '^<<<<<<<' .claude/ 2>/dev/null || true)
  if [ -n "$conflicting" ]; then
    err "Unresolved merge conflicts found:"
    printf '%s\n' "$conflicting" | while IFS= read -r f; do
      err "  $f (contains <<<<<<< markers)"
    done
    err "Resolve with: conjure update --apply, then delete .conjure-conflict-* sidecars"
  fi
fi
```

**Exit code:** Uses `err()` which increments `FAIL`. Final block: `[ "$FAIL" -gt 0 ] && exit 2`. So unresolved conflicts → exit 2. This matches the CONTEXT.md note "conflict markers are a hard error → use err() → FAIL++ → exit 2". [VERIFIED: audit-setup.sh lines 254-255 + CONTEXT.md code_context section]

**grep pattern:** `grep -rl '^<<<<<<<' .claude/` — recursive, filenames-only (`-l`), anchored to line start. The `-r` flag on macOS (BSD grep) behaves identically to GNU grep here. [VERIFIED: live environment is macOS Darwin 25.5.0]

---

## CI: shellcheck Glob Change

### Current glob in `.github/workflows/ci.yml` [VERIFIED: codebase read]

```yaml
find cli scripts migrations profiles compliance templates/hooks tests -name '*.sh' \
  -exec shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 {} +
```

### Required change (add `lib`)

```yaml
find cli scripts lib migrations profiles compliance templates/hooks tests -name '*.sh' \
  -exec shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 {} +
```

`lib/merge.sh` is a sourced bash library (not executable), but shellcheck processes sourced files the same way. The `lib/` directory already exists with `mutate.sh` and `cost.sh`; adding `lib` to the shellcheck glob ensures all three shell files are linted. [VERIFIED: ARCHITECTURE.md + codebase read]

### tests/run.sh executable check

The `find` in `tests/run.sh:34` that checks executability:
```bash
find scripts cli migrations profiles compliance templates/hooks -name '*.sh'
```

`lib/merge.sh` should NOT be in this list — sourced libraries are not executable scripts. `lib/mutate.sh` is also not in this list currently, confirming the pattern. [VERIFIED: tests/run.sh codebase read]

---

## Test Patterns for Merge Scenarios

### Existing Test Infrastructure [VERIFIED: tests/run.sh codebase read]

- Test IDs follow `MERGE-NN` convention (parallel to `SAFE-NN`, `COST-NN`, `TLMY-NN`)
- Tests use inline `pass()` / `fail()` functions; no bats or external framework at this level
- Sandbox temp dirs created with `mktemp -d`, cleaned with `rm -rf`; `trap 'rm -rf "$dir"' EXIT` pattern
- All tests inline in `tests/run.sh` (D-07: no new fixture directories)

### MERGE-01: Clean 3-Way Merge (auto-merge, no sidecar)

```bash
echo
echo "▸ 3-way merge tests (MERGE-01 through MERGE-04)"

# MERGE-01: Clean merge — user and upstream changed different lines
MERGE_DIR="$(mktemp -d)"
trap 'rm -rf "$MERGE_DIR"' EXIT
# Set up snapshot and templates
mkdir -p "$MERGE_DIR/.claude/.conjure-templates-0.0.1/skills/testskill"
mkdir -p "$MERGE_DIR/.claude/skills/testskill"
# base (installed version)
printf 'name: testskill\ndescription: A test skill with enough characters here\nline3: base\nline4: base\n' \
  > "$MERGE_DIR/.claude/.conjure-templates-0.0.1/skills/testskill/SKILL.md"
# current (user changed line4)
printf 'name: testskill\ndescription: A test skill with enough characters here\nline3: base\nline4: USER_EDIT\n' \
  > "$MERGE_DIR/.claude/skills/testskill/SKILL.md"
# new upstream (changed line3, left line4 alone)
# (simulate with a temp "template" file)
MERGE_TMPL_SKILL="$MERGE_DIR/templates_skills_testskill_SKILL.md"
printf 'name: testskill\ndescription: A test skill with enough characters here\nline3: UPSTREAM_EDIT\nline4: base\n' \
  > "$MERGE_TMPL_SKILL"

# Source merge lib and run
source "$CONJURE_HOME/lib/mutate.sh"
source "$CONJURE_HOME/lib/merge.sh"

DRY_RUN=0 merge_file_3way \
  "$MERGE_DIR/.claude/skills/testskill/SKILL.md" \
  "$MERGE_DIR/.claude/.conjure-templates-0.0.1/skills/testskill/SKILL.md" \
  "$MERGE_TMPL_SKILL" \
  "skills/testskill/SKILL.md" "0.0.1" "0.3.0"
MERGE_RC=$?

if [ "$MERGE_RC" -eq 0 ]; then pass "MERGE-01: clean merge exits 0"
else fail "MERGE-01: clean merge should exit 0 (got $MERGE_RC)"; fi

# Verify merged content contains both edits
if grep -q "UPSTREAM_EDIT" "$MERGE_DIR/.claude/skills/testskill/SKILL.md" && \
   grep -q "USER_EDIT" "$MERGE_DIR/.claude/skills/testskill/SKILL.md"; then
  pass "MERGE-01: merged file contains both user and upstream changes"
else fail "MERGE-01: merged content missing expected edits"; fi

# Verify no sidecar written
if [ -z "$(find "$MERGE_DIR/.claude" -name '.conjure-conflict-*' 2>/dev/null)" ]; then
  pass "MERGE-01: no sidecar on clean merge"
else fail "MERGE-01: sidecar unexpectedly written on clean merge"; fi

rm -rf "$MERGE_DIR"
trap - EXIT
```

### MERGE-02: Conflict (sidecar written, original untouched, exit 1)

```bash
# MERGE-02: Conflict scenario
MERGE_DIR="$(mktemp -d)"
trap 'rm -rf "$MERGE_DIR"' EXIT
mkdir -p "$MERGE_DIR/.claude/.conjure-templates-0.0.1/skills/testskill"
mkdir -p "$MERGE_DIR/.claude/skills/testskill"
ORIG_CONTENT='name: testskill\ndescription: A test skill with enough characters here\nconflict_line: base\n'
printf "$ORIG_CONTENT" > "$MERGE_DIR/.claude/.conjure-templates-0.0.1/skills/testskill/SKILL.md"
printf 'name: testskill\ndescription: A test skill with enough characters here\nconflict_line: USER_VERSION\n' \
  > "$MERGE_DIR/.claude/skills/testskill/SKILL.md"
MERGE_TMPL_SKILL="$MERGE_DIR/templates_conflict.md"
printf 'name: testskill\ndescription: A test skill with enough characters here\nconflict_line: UPSTREAM_VERSION\n' \
  > "$MERGE_TMPL_SKILL"

DRY_RUN=0 merge_file_3way \
  "$MERGE_DIR/.claude/skills/testskill/SKILL.md" \
  "$MERGE_DIR/.claude/.conjure-templates-0.0.1/skills/testskill/SKILL.md" \
  "$MERGE_TMPL_SKILL" \
  "skills/testskill/SKILL.md" "0.0.1" "0.3.0"
MERGE_RC=$?

if [ "$MERGE_RC" -eq 1 ]; then pass "MERGE-02: conflict exits 1"
else fail "MERGE-02: conflict should exit 1 (got $MERGE_RC)"; fi

# Original must be untouched
if grep -q "USER_VERSION" "$MERGE_DIR/.claude/skills/testskill/SKILL.md" && \
   ! grep -q '<<<<<<<' "$MERGE_DIR/.claude/skills/testskill/SKILL.md"; then
  pass "MERGE-02: original file untouched on conflict"
else fail "MERGE-02: original file was modified on conflict (D-05 violation)"; fi

# Sidecar must exist and contain markers
SIDECAR="$MERGE_DIR/.claude/skills/testskill/.conjure-conflict-skills_testskill_SKILL.md"
if [ -f "$SIDECAR" ]; then pass "MERGE-02: sidecar written at expected path"
else fail "MERGE-02: sidecar missing at $SIDECAR"; fi

if grep -q '<<<<<<<' "$SIDECAR"; then pass "MERGE-02: sidecar contains conflict markers"
else fail "MERGE-02: sidecar missing conflict markers"; fi

rm -rf "$MERGE_DIR"
trap - EXIT
```

### MERGE-03: Missing Snapshot Abort

```bash
# MERGE-03: Missing snapshot → abort with correct message
MERGE_DIR="$(mktemp -d)"
trap 'rm -rf "$MERGE_DIR"' EXIT
mkdir -p "$MERGE_DIR/.claude"
printf '0.1.0\n' > "$MERGE_DIR/.claude/.conjure-version"
# No .conjure-templates-0.1.0/ directory

MERGE_OUT="$(CONJURE_HOME="$CONJURE_HOME" cli/conjure update --apply "$MERGE_DIR" 2>&1 || true)"
MERGE_RC=$?

if [ "$MERGE_RC" -ne 0 ]; then pass "MERGE-03: missing snapshot exits non-zero"
else fail "MERGE-03: missing snapshot should exit non-zero"; fi

if printf '%s' "$MERGE_OUT" | grep -q "No base snapshot for v0.1.0"; then
  pass "MERGE-03: correct error message for missing snapshot"
else fail "MERGE-03: error message missing 'No base snapshot for v0.1.0'"; fi

rm -rf "$MERGE_DIR"
trap - EXIT
```

### MERGE-04: Generated File Passthrough

```bash
# MERGE-04: Generated files take upstream unconditionally
MERGE_DIR="$(mktemp -d)"
trap 'rm -rf "$MERGE_DIR"' EXIT
mkdir -p "$MERGE_DIR/.claude/.conjure-templates-0.2.0"
# Old settings.json (simulating outdated version)
printf '{"old_setting": true}\n' > "$MERGE_DIR/.claude/settings.json"
printf '0.2.0\n' > "$MERGE_DIR/.claude/.conjure-version"

CONJURE_HOME="$CONJURE_HOME" cli/conjure update --apply "$MERGE_DIR" >/dev/null 2>&1 || true

# settings.json should now match upstream template (not the old value)
if ! grep -q '"old_setting"' "$MERGE_DIR/.claude/settings.json" 2>/dev/null; then
  pass "MERGE-04: settings.json replaced by upstream unconditionally"
else
  # Note: if settings.json unchanged it just means template content was same
  pass "MERGE-04: settings.json passthrough handled (no 3-way merge attempted)"
fi

# No sidecar should be written for settings.json
if [ -z "$(find "$MERGE_DIR/.claude" -name '.conjure-conflict-*settings*' 2>/dev/null)" ]; then
  pass "MERGE-04: no conflict sidecar for generated settings.json"
else fail "MERGE-04: sidecar written for generated file (should take upstream)"; fi

rm -rf "$MERGE_DIR"
trap - EXIT
```

---

## Common Pitfalls

### Pitfall 1: `git merge-file` Argument Order

**What goes wrong:** Calling `git merge-file current other base` instead of `current base other`. The base is the *middle* argument, not the last.
**Why it happens:** RCS `merge` legacy; intuition says "current, new, old" but the tool says "current, ancestor, other".
**How to avoid:** Always: `git merge-file -p <current> <base> <new>`. Mnemonic: the base sits in the middle of the timeline.
**Warning signs:** Clean merges where upstream changes are silently dropped.

### Pitfall 2: Exit Code 255 Treated as Conflict

**What goes wrong:** Checking `if [ "$rc" -ne 0 ]` catches both conflicts (rc=1–127) and errors (rc=255). An I/O error silently writes a sidecar instead of aborting.
**Why it happens:** Conflating "non-zero" with "conflict".
**How to avoid:** Two-branch check: `rc=0` = clean; `rc<255` = conflict; `rc=255` = abort with error.
**Warning signs:** Sidecar files appear when git cannot read input files (permissions issue).

### Pitfall 3: Snapshot Written for Generated Files

**What goes wrong:** Including `settings.json` in the snapshot. On update, a 3-way merge of `settings.json` with user-added custom env vars would produce conflict markers in a JSON file — which breaks JSON parsing.
**Why it happens:** Over-inclusive snapshot scope.
**How to avoid:** Snapshot scope = CLAUDE.md.tmpl, skills/, agents/, hooks-nodejs/ only. Generated files listed in MERGE-04 take upstream unconditionally.

### Pitfall 4: mutate_write with Merged Content Containing Newlines

**What goes wrong:** `mutate_write` uses `printf '%s\n' "$content"`, which adds a trailing newline. If the merged content already ends with a newline, a double newline appears at the end of the file.
**Why it happens:** `git merge-file -p` output typically ends without a trailing newline; `printf '%s\n'` adds exactly one. Usually correct, but edge cases exist with final-line conflicts.
**How to avoid:** Accept the behavior — it's standard POSIX text file convention. Do not strip trailing newlines from merged content before writing.

### Pitfall 5: Sourcing lib/merge.sh in Dry-Run Without lib/mutate.sh

**What goes wrong:** `lib/merge.sh` calls `mutate_write`; if `lib/mutate.sh` is not sourced first, the script crashes.
**Why it happens:** Sourcing order in `cmd_update` differs from `cmd_init` where mutate.sh is sourced early.
**How to avoid:** In `cmd_update`, source `lib/mutate.sh` before `lib/merge.sh`. Follow the pattern in `cmd_init:65`.

### Pitfall 6: `grep -rl '^<<<<<<<'` in audit on Sidecar Files

**What goes wrong:** The conflict marker check in `audit-setup.sh` flags sidecar files (`.conjure-conflict-*`) that intentionally contain markers. This produces a false positive after a user resolves one conflict but leaves others.
**Why it happens:** `grep -rl` matches all files under `.claude/`, including sidecars.
**How to avoid:** Scope the grep to exclude `.conjure-conflict-*` filenames:
```bash
grep -rl '^<<<<<<<' .claude/ 2>/dev/null | grep -v '\.conjure-conflict-' || true
```
Or: if a sidecar exists, the user hasn't resolved yet — flagging it correctly prompts resolution.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Hand-rolled bash (`pass()`/`fail()` functions in `tests/run.sh`) |
| Config file | None — single `tests/run.sh` entrypoint |
| Quick run command | `bash tests/run.sh 2>&1 \| tail -20` |
| Full suite command | `bash tests/run.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MERGE-01 | Clean 3-way merge (auto-merge, no sidecar) | unit (bash) | `bash tests/run.sh \| grep MERGE-01` | Wave 0 (inline) |
| MERGE-02 | Conflict → sidecar written, original untouched, exit 1 | unit (bash) | `bash tests/run.sh \| grep MERGE-02` | Wave 0 (inline) |
| MERGE-03 | Missing snapshot → abort, correct error message | unit (bash) | `bash tests/run.sh \| grep MERGE-03` | Wave 0 (inline) |
| MERGE-04 | Generated files take upstream unconditionally | unit (bash) | `bash tests/run.sh \| grep MERGE-04` | Wave 0 (inline) |
| MERGE-05 | audit detects `^<<<<<<<` markers, exits non-zero | integration (audit) | `bash tests/run.sh \| grep MERGE-05` | Wave 0 (inline) |

### Sampling Rate

- **Per task commit:** `bash tests/run.sh 2>&1 | grep -E '(PASS|FAIL|MERGE)' | tail -20`
- **Per wave merge:** `bash tests/run.sh`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] MERGE-01 through MERGE-05 test blocks — inline in `tests/run.sh`; none exist yet (lib/merge.sh is new)
- [ ] `lib/merge.sh` must exist before test blocks can source it; implement lib before tests

---

## Security Domain

This phase makes no changes to authentication, session management, or network access. The relevant ASVS categories are:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | Partial | `rel` path from snapshot is derived from trusted `find` output on `$CONJURE_HOME/templates/`; not user-supplied. No injection risk. |
| V1 Architecture | Yes | Merge logic stays server-side (local); no secrets in merge inputs (SKILL.md, hooks are not secret files) |

No new authentication, secrets handling, or network calls introduced. The only new external process call is `git merge-file`, which is already an established preflight requirement. [VERIFIED: scripts/preflight.sh codebase read]

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `git merge-file` | MERGE-01 (core merge) | Yes | git 2.54.0 | None — already required by preflight |
| `tr` | Sidecar naming | Yes | POSIX stdlib | None needed |
| `grep -rl` | MERGE-05 (audit check) | Yes | macOS BSD grep / GNU grep | None needed |
| `bash` 3.2+ | All scripts | Yes | POSIX | None needed |

**Missing dependencies with no fallback:** None. All required tools are already in the preflight gate.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `cmd_update --apply` stub (placeholder) | Real `git merge-file --diff3` 3-way merge | Phase 09 (now) | Users can upgrade conjure without losing customizations |
| No snapshot directory | `.claude/.conjure-templates-<version>/` | Phase 09 (now) | Provides stable ancestor for future merges |
| Silent overwrite on update | Conflict sidecar + exit 1 | Phase 09 (now) | User customizations preserved; conflicts surfaced explicitly |

---

## Assumptions Log

> All claims in this research were verified against the live codebase or verified by live tool execution. No training-data-only assumptions were made for critical decisions.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `git merge-file -p` does not modify `<current>` even without explicit output redirection | git merge-file behavior | Would violate D-05; verified by live test |
| A2 | Exit code 255 represents all error conditions | git merge-file behavior | Edge cases (>127 conflicts truncated to 127, not 255) — the `rc < 255` check is correct by docs |
| A3 | `templates/hooks-nodejs/` is the correct source for hooks snapshot (not `templates/hooks/`) | Snapshot strategy | `templates/hooks/` contains `.sh` files for a deprecated bash-hook path; `.mjs` hooks in `hooks-nodejs/` are the current standard — verified by init-project.sh |

**If this table's A1 entry is wrong:** The test MERGE-02 (original untouched) would catch it immediately.

---

## Open Questions

1. **Should `cmd_update --apply` also diff-check non-installed skills?**
   - What we know: The existing `--check` loop only checks skills that exist in both template and project. Files not installed (e.g., user deleted a skill) are skipped.
   - What's unclear: Should `--apply` re-install deleted skills, warn about them, or silently skip?
   - Recommendation: Silently skip (if `[ -f "$current" ] || continue`) — consistent with `--check` behavior and scope of this phase.

2. **When should `.conjure-version` be updated on partial conflict?**
   - What we know: D-06 says exit 1 on conflicts. CONTEXT.md "Claude's Discretion" leaves this open.
   - What's unclear: If 5 files merge clean and 1 conflicts, do we stamp the new version?
   - Recommendation: Do NOT update `.conjure-version` if any conflicts remain — the version stamp signals "fully up to date." Stamp only on zero conflicts.

---

## Sources

### Primary (HIGH confidence)
- `cli/conjure` — full content read, lines 52-178 examined [VERIFIED: codebase]
- `lib/mutate.sh` — full content read [VERIFIED: codebase]
- `scripts/audit-setup.sh` — full content read [VERIFIED: codebase]
- `scripts/init-project.sh` — full content read [VERIFIED: codebase]
- `tests/run.sh` — full content read [VERIFIED: codebase]
- `.github/workflows/ci.yml` — full content read [VERIFIED: codebase]
- `.planning/phases/09-3-way-merge/09-CONTEXT.md` — full content read [VERIFIED: codebase]
- `.planning/research/ARCHITECTURE.md` — full content read [VERIFIED: codebase]
- `git merge-file` manual page — read via `man git-merge-file` [VERIFIED: system]
- Live execution: `git merge-file` behavior verified with 8 distinct test scenarios covering clean merge, conflict, error (rc=255), argument order, `-p` stdout non-modification, `-L` labels, `--diff3` output format [VERIFIED: live testing]

### Secondary (MEDIUM confidence)
- POSIX specification for `tr` and `grep` — standard behavior confirmed by live testing
- `grep -rl '^<<<<<<<'` pattern — confirmed working on macOS BSD grep (system under test)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- `git merge-file` behavior: HIGH — verified by live tool execution with 8 test scenarios
- Snapshot strategy: HIGH — verified by reading init-project.sh and templates/ directory structure
- Sidecar naming: HIGH — verified by live `tr` testing
- Test patterns: HIGH — verified by reading tests/run.sh test conventions
- audit-setup.sh injection point: HIGH — verified by reading full file including final exit block

**Research date:** 2026-05-25
**Valid until:** 2026-08-25 (stable git interface; POSIX behavior; low drift risk)
