# Phase 09: 3-Way Merge - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 4 (1 new, 3 modified)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/merge.sh` | library (sourced) | file-I/O + transform | `lib/mutate.sh` | exact role-match |
| `cli/conjure` (cmd_update --apply + cmd_init snapshot) | controller/dispatcher | request-response | `cli/conjure:cmd_init` (existing) | exact — same file |
| `scripts/audit-setup.sh` (conflict marker check) | worker script | CRUD / check | `scripts/audit-setup.sh` (existing body) | exact — same file |
| `tests/run.sh` (MERGE-NN blocks) | test | batch / assertion | `tests/run.sh` COST-NN and TEST-NN blocks | exact — same file |
| `.github/workflows/ci.yml` (shellcheck glob) | config | N/A | `ci.yml` line 22-23 (existing find command) | exact — same file |

---

## Pattern Assignments

### `lib/merge.sh` (new library, sourced)

**Analog:** `lib/mutate.sh` (entire file — 76 lines)

**File header pattern** (`lib/mutate.sh` lines 1-13):
```bash
#!/usr/bin/env bash
# lib/mutate.sh — sourced mutation chokepoint for Conjure.
# Source this file; call mutate_mkdir, mutate_cp, mutate_write, mutate_summary.
# Requires: DRY_RUN env var (0=live, 1=dry); set -u safe via ${DRY_RUN:-0}.
# POSIX bash 3.2+ compatible. No associative arrays, no mapfile, no local -n.
#
# Usage from any script:
#   source "$CONJURE_HOME/lib/mutate.sh"
#   mutate_mkdir  <dir>
#   mutate_cp     <src> <dest>
#   mutate_write  <dest> <content> [--append]
#   mutate_summary   # call at end of each script
```

Follow the same header template for `lib/merge.sh`:
- File-level doc comment naming all public functions and their signatures
- Note POSIX bash 3.2+ compat and the `DRY_RUN` dependency
- No shebang-based execution — sourced only

**No `set -euo pipefail` in lib files** — lib files are sourced, not executed. The calling script owns the error mode. `lib/mutate.sh` has no `set -e` at top level; neither should `lib/merge.sh`.

**Module-level state initialization pattern** (`lib/mutate.sh` lines 14-16):
```bash
# Initialize dry-run mutation counter if not already set.
# Safe under set -u; idempotent on re-source.
CONJURE_DRY_MUTATION_COUNT="${CONJURE_DRY_MUTATION_COUNT:-0}"
```

`lib/merge.sh` should initialize its own conflict-tracking counter in the same style:
```bash
CONJURE_MERGE_CONFLICT_COUNT="${CONJURE_MERGE_CONFLICT_COUNT:-0}"
CONJURE_MERGE_CONFLICT_FILES=""
```

**DRY_RUN guard pattern** (`lib/mutate.sh` lines 33-44):
```bash
mutate_cp() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would cp $1 $2"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  if [ -d "$1" ]; then
    cp -r "$1" "$2"
  else
    cp "$1" "$2"
  fi
}
```

Every function in `lib/merge.sh` that writes to the filesystem (e.g. writing the sidecar file) must open with the same `[ "${DRY_RUN:-0}" = "1" ]` guard before touching disk, and must print `[dry-run] would write <dest>` + increment `CONJURE_DRY_MUTATION_COUNT`.

**`local` variable pattern** (`lib/mutate.sh` lines 51-53):
```bash
mutate_write() {
  local dest="$1"
  local content="$2"
  local mode="${3:-}"
```

All functions in `lib/merge.sh` must declare parameters as `local` immediately on entry — one `local` per line. No `local a b c` shorthand (shellcheck SC2155 rule already enforced by CI).

**printf over echo for portable file writes** (`lib/mutate.sh` lines 59-63):
```bash
  if [ "$mode" = "--append" ]; then
    printf '%s\n' "$content" >> "$dest"
  else
    printf '%s\n' "$content" > "$dest"
  fi
```

In `lib/merge.sh`, sidecar content comes from `git merge-file -p` stdout, which is captured into a variable. Write it with `printf '%s\n' "$sidecar_content" > "$sidecar_path"` (or route through `mutate_write`). Never use `echo -e` or `cat <<EOF` for file output.

---

### `cli/conjure` — `cmd_update --apply` stub replacement (lines 174-178)

**Analog:** `cmd_init` in `cli/conjure` lines 52-90 (same function pattern in same file)

**Source pattern for a lib file** (`cli/conjure` lines 65-66):
```bash
  source "$CONJURE_HOME/lib/mutate.sh" \
    || { echo "✗ Failed to load lib/mutate.sh — check CONJURE_HOME ($CONJURE_HOME)"; return 1; }
```

`cmd_update --apply` must source `lib/merge.sh` with the identical guard:
```bash
  source "$CONJURE_HOME/lib/merge.sh" \
    || { echo "✗ Failed to load lib/merge.sh — check CONJURE_HOME ($CONJURE_HOME)"; return 1; }
```

Note: `lib/mutate.sh` must also be sourced (for `mutate_cp` / `mutate_write` used by the backup step). Since `cmd_update` currently does NOT source either lib file, both sources are added in the `--apply` branch (or at the top of the function).

**DRY_RUN threading pattern** (`cli/conjure` lines 64, 78, 83):
```bash
  DRY_RUN="$dryrun"
  ...
  CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" bash "$CONJURE_HOME/scripts/init-project.sh" "$mode" "$target"
  ...
  CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" bash "$CONJURE_HOME/profiles/$profile/apply.sh" "$target"
```

`cmd_update` does not yet have a `--dry-run` flag (the stub has no `dryrun` local). Phase 09 does NOT add `--dry-run` to `cmd_update` (out of scope). The `DRY_RUN` env var is threaded through sourced lib files via the module-level `${DRY_RUN:-0}` default — `lib/merge.sh` functions use `${DRY_RUN:-0}` directly.

**Version stamp write pattern** (`cli/conjure` lines 86-88):
```bash
  mutate_write "$target/.claude/.conjure-version" "$CONJURE_VERSION"
  mutate_summary
  echo "▸ Pinned conjure version: $CONJURE_VERSION"
```

After a clean merge in `--apply`, update the version stamp with the same `mutate_write` call. `mutate_summary` is called at the end of the apply run (once, after the loop).

**Backup-before-mutate pattern** (`cli/conjure` lines 104-109 in `cmd_migrate`):
```bash
  # Backup target's existing .claude/ before any mutation
  if [ -d "$target/.claude" ]; then
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local backup="$target/.claude.backup-$ts"
    echo "▸ Backing up existing .claude/ → $backup"
    [ "$dryrun" = 0 ] && cp -R "$target/.claude" "$backup"
  fi
```

`cmd_update --apply` must perform the same backup before the merge loop starts. Copy this block verbatim, replacing `$dryrun` with `0` (since `cmd_update` currently has no dryrun flag) or guarding with `[ "${DRY_RUN:-0}" = "0" ]`.

**Flag-parsing loop pattern** (`cli/conjure` lines 54-63):
```bash
  while [ $# -gt 0 ]; do
    case "$1" in
      new|existing|migrate) mode="$1" ;;
      --profile=*)          profile="${1#--profile=}" ;;
      --dry-run)            dryrun=1 ;;
      --help|-h)            grep -A3 '^  conjure init' <<<"$(usage)"; return 0 ;;
      *)                    target="$1" ;;
    esac
    shift
  done
```

`cmd_update` already parses `--check|--apply` and a positional `target` with the same `while [ $# -gt 0 ]` + `case` pattern (lines 134-140). The replacement stub at lines 174-178 does NOT change the flag-parsing block — only the body of the `--apply` branch changes.

---

### `cli/conjure` — `cmd_init` snapshot write (after line 87)

**Exact insertion point:** after `mutate_write "$target/.claude/.conjure-version" "$CONJURE_VERSION"` (line 87), before `mutate_summary` (line 88).

**Pattern to follow for the snapshot write loop** (analog: `scripts/init-project.sh` lines 50-56 — the hooks copy loop):
```bash
# 4. Copy hooks (node .mjs — works on all platforms including Windows)
for hook in "$KIT"/templates/hooks-nodejs/*.mjs; do
  name=$(basename "$hook")
  if [ ! -f ".claude/hooks/$name" ]; then
    mutate_cp "$hook" ".claude/hooks/$name"
    echo "  ✓ created .claude/hooks/$name"
  fi
done
```

The snapshot write follows the same `for f in <source-glob>; do ... mutate_cp ... done` structure. It iterates the user-owned template files (CLAUDE.md.tmpl, skills/, agents/, hooks/) and writes them into `.claude/.conjure-templates-$CONJURE_VERSION/`. Uses `mutate_mkdir` to create the snapshot dir first, then `mutate_cp` for each file/directory.

The `echo "▸ Pinned conjure version: $CONJURE_VERSION"` message at line 89 can be accompanied by:
```bash
echo "▸ Snapshot written: $target/.claude/.conjure-templates-$CONJURE_VERSION/"
```

---

### `scripts/audit-setup.sh` — conflict marker detection

**Analog:** Existing check blocks within `scripts/audit-setup.sh`

**ok/warn/err helper pattern** (`scripts/audit-setup.sh` lines 14-17):
```bash
note() { echo "  $1"; }
ok()   { note "✓ $1"; PASS=$((PASS+1)); }
warn() { note "⚠ $1"; WARN=$((WARN+1)); }
err()  { note "✗ $1"; FAIL=$((FAIL+1)); }
```

Use `err` (not `warn`) for conflict markers — per CONTEXT.md §specifics, conflict markers are a hard error (exit 2 via `$FAIL > 0`).

**Grep-based check block pattern** (`scripts/audit-setup.sh` lines 31-35):
```bash
  if grep -q '^@' CLAUDE.md; then
    err "CLAUDE.md contains @imports — they load eagerly. Replace with prose links."
  else
    ok "CLAUDE.md: no @imports"
  fi
```

The conflict marker check follows the same pattern. For detecting multiple files, use the `grep -rl` variant:
```bash
# Conflict markers
CONFLICT_FILES="$(grep -rl '^<<<<<<<' .claude/ 2>/dev/null || true)"
if [ -n "$CONFLICT_FILES" ]; then
  err "Conflict markers found in .claude/ — resolve and delete .conjure-conflict-* sidecars"
  while IFS= read -r cf; do
    note "  conflict markers: $cf"
  done <<< "$CONFLICT_FILES"
else
  ok ".claude/: no conflict markers"
fi
```

**Insertion point:** Before the final summary block at `scripts/audit-setup.sh` lines 132-136. The conflict check must be guarded by `[ -d .claude ]` (the .claude directory check already exits early at line 44 — so by the time we reach the insertion point, `.claude/` is guaranteed to exist).

**Exit code mapping** (`scripts/audit-setup.sh` lines 254-256):
```bash
[ "$FAIL" -gt 0 ] && exit 2
[ "$WARN" -gt 0 ] && exit 1
exit 0
```

Conflict markers route to `err` → `$FAIL` → `exit 2`. This is correct per CONTEXT.md.

---

### `tests/run.sh` — MERGE-NN test blocks

**Analog:** COST-01 through COST-03 block (`tests/run.sh` lines 378-445), plus TEST-01/TEST-04 sandbox blocks (lines 252-314).

**Section header pattern** (`tests/run.sh` lines 378-379, 448):
```bash
echo
echo "▸ Merge tests (MERGE-01, MERGE-02, MERGE-03, MERGE-04)"
```

Each logical group of related test IDs gets one `echo "▸ ..."` header with the ID range.

**Sandbox setup + teardown pattern** (`tests/run.sh` lines 380-382, 444-445):
```bash
COST_FX="$CONJURE_HOME/tests/fixtures/python-fastapi"
sandbox_setup "$COST_FX"
trap 'rm -rf "$SANDBOX_DIR"' EXIT
...
rm -rf "$SANDBOX_DIR"
trap - EXIT
```

Each MERGE test block that needs an isolated filesystem:
1. Sets up a fixture path (or a fresh `mktemp -d` for synthetic scenarios)
2. Calls `sandbox_setup` (which registers its own EXIT trap) or manually manages via `mktemp -d` + trap
3. Runs the scenario
4. Asserts with `pass`/`fail`
5. Calls `rm -rf "$SANDBOX_DIR"` + `trap - EXIT` to clear

For synthetic (non-fixture) scenarios that do not use `sandbox_setup`, follow the FM-1 pattern at lines 338-348:
```bash
FM_DIR="$(mktemp -d)"
# ... set up synthetic scenario ...
FM_OUT="$(bash "$CONJURE_HOME/scripts/..." "$FM_DIR" 2>&1 || true)"
if printf '%s\n' "$FM_OUT" | grep -q "expected string"; then
  pass "description (MERGE-NN)"
else
  fail "description (MERGE-NN)"
fi
rm -rf "$FM_DIR"
```

**pass/fail assertion pattern** (`tests/run.sh` lines 15-16):
```bash
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
```

Assertion call convention: always include the test ID in the message string as a suffix:
```bash
pass "clean merge produced no sidecar (MERGE-01)"
fail "clean merge produced no sidecar (MERGE-01)"
```

**Exit-code assertion pattern** (`tests/run.sh` lines 259-261, 276-281):
```bash
  if [ "$AUDIT_RC" -eq 0 ]; then
    pass "fixture audit green: $prof"
  else
    fail "fixture audit non-green (rc=$AUDIT_RC): $prof"
```

For MERGE tests that assert non-zero exit (conflict scenario, missing snapshot):
```bash
MERGE_RC=0
bash "$CONJURE_HOME/cli/conjure" update --apply "$MERGE_DIR" >/dev/null 2>&1 || MERGE_RC=$?
if [ "$MERGE_RC" -ne 0 ]; then
  pass "conflict scenario exits non-zero (MERGE-02)"
else
  fail "conflict scenario should exit non-zero (MERGE-02)"
fi
```

**Capture stdout+stderr** (pattern from lines 275, 384):
```bash
BROKEN_OUT="$(bash "$CONJURE_HOME/scripts/audit-setup.sh" "$SANDBOX_DIR" 2>&1)"
```

Use `MERGE_OUT="$(... 2>&1 || true)"` when the command is expected to fail and you need its output for assertions.

**Test IDs for the four required scenarios (D-08):**
- `MERGE-01` — clean 3-way merge (different lines changed → auto-merge, no sidecar, exit 0)
- `MERGE-02` — conflict scenario (same lines changed → sidecar written, original untouched, exit 1)
- `MERGE-03` — missing snapshot abort (no `.conjure-templates-<version>/` → exit non-zero, error message)
- `MERGE-04` — generated-file passthrough (`.conjure-version` + `settings.json` → take upstream unconditionally)

---

### `.github/workflows/ci.yml` — shellcheck glob update

**Current shellcheck find command** (`ci.yml` lines 22-23):
```yaml
      - name: Lint shell scripts
        run: |
          find cli scripts migrations profiles compliance templates/hooks tests -name '*.sh' \
            -exec shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 {} +
```

**Required change:** Add `lib` to the directory list so `lib/merge.sh` is covered:
```yaml
          find cli scripts migrations profiles compliance templates/hooks tests lib -name '*.sh' \
            -exec shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 {} +
```

The suppressed codes (`SC2164,SC2044,SC2034,SC2155`) are project-wide suppressions — do not add or remove any. `lib/merge.sh` must be written to pass shellcheck clean with those exact suppressions.

---

## Shared Patterns

### DRY_RUN guard (applies to all functions in `lib/merge.sh`)
**Source:** `lib/mutate.sh` lines 22-27 and 33-37
```bash
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would <action> <args>"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
```
Every function that touches the filesystem opens with this guard. Increment `CONJURE_DRY_MUTATION_COUNT` (not a merge-specific counter) so the existing `mutate_summary` call in `cmd_init` reports all suppressed mutations including snapshot writes.

### Error messaging style (applies to all new user-visible messages)
**Source:** `cli/conjure` lines 66, 99-100
```bash
echo "✗ Failed to load lib/mutate.sh — check CONJURE_HOME ($CONJURE_HOME)"
echo "✗ No migration script for source: $source"
echo "  Available: $(ls ...)"
```
- Fatal messages: `echo "✗ <message>"` then `return 1` (inside functions) or `exit 2` (inside scripts)
- Advisory sub-lines: `echo "  <detail>"` (two-space indent)
- Progress messages: `echo "▸ <message>"`

The missing-snapshot error (D-01) follows this pattern:
```bash
echo "✗ No base snapshot for v$pinned. Re-run 'conjure init' to write one, then update."
return 1
```

### Test output format (applies to all MERGE-NN assertions)
**Source:** `tests/run.sh` lines 15-16, 388-392
```bash
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
```
Message format: `"<brief description> (<TEST-ID>)"` — test ID always last in parens. Do not add color codes. Do not call `exit` inside test assertions — the final `[ "$FAIL" -eq 0 ]` (line 612) handles overall exit.

### Sourcing lib files in scripts (applies to `scripts/init-project.sh` pattern)
**Source:** `scripts/init-project.sh` lines 12-13
```bash
KIT="$(cd "$(dirname "$0")/.." && pwd)"
source "$KIT/lib/mutate.sh"
```
Worker scripts resolve `KIT` (or `CONJURE_HOME` when passed as env) and source lib files at the top. `lib/merge.sh` is sourced from `cli/conjure` (not from a standalone script), so it uses `$CONJURE_HOME` directly.

### Conflict sidecar path encoding (specific to `lib/merge.sh`)
**Source:** CONTEXT.md §D-04
```
.claude/skills/architecture/SKILL.md
  → sidecar: .conjure-conflict-skills_architecture_SKILL.md
  → placed next to original: .claude/skills/architecture/.conjure-conflict-skills_architecture_SKILL.md
```
Encode the relative path from `.claude/` by replacing `/` with `_`, then prefix `.conjure-conflict-`. In bash:
```bash
local rel_from_claude="${live_file#$target/.claude/}"
local encoded; encoded="$(printf '%s' "$rel_from_claude" | tr '/' '_')"
local sidecar_dir; sidecar_dir="$(dirname "$live_file")"
local sidecar_path="$sidecar_dir/.conjure-conflict-$encoded"
```

### Audit check placement (specific to `scripts/audit-setup.sh`)
**Source:** `scripts/audit-setup.sh` line 132 (before summary block) — insert just before:
```bash
echo
echo "─────────────────────────────────────"
echo "PASS: $PASS    WARN: $WARN    FAIL: $FAIL"
```
The conflict-marker grep check block goes directly above these three lines so it is always evaluated and counted in the summary.

---

## Template Directory Structure Reference

Files the snapshot must cover (per D-03 — user-owned templates only):

```
templates/
  CLAUDE.md.tmpl
  skills/
    _anatomy/SKILL.md
    api-routes/SKILL.md
    architecture/SKILL.md
    ast-search/SKILL.md
    build-deploy/SKILL.md
    code-graph/SKILL.md
    data-access/SKILL.md
    database-schema/SKILL.md
    debugging/SKILL.md
    docs-lookup/SKILL.md
    domain-model/SKILL.md
    messaging/SKILL.md
    pr-review/SKILL.md
    release/SKILL.md
    repo-pack/SKILL.md
    security-review/SKILL.md
    sql-explorer/SKILL.md
    testing/SKILL.md
    web-research/SKILL.md
  agents/
    code-explorer.md
    diff-reviewer.md
    doc-writer.md
    migration-writer.md
    security-auditor.md
    test-writer.md
  hooks-nodejs/
    post-edit-format.mjs
    pre-bash-block-destructive.mjs
    pre-commit-quality-gate.mjs
    session-start-context.mjs
    skill-telemetry.mjs
    stop-compound-engineering.mjs
```

NOT snapshotted (generated files, take upstream unconditionally per D-03):
- `settings.json.tmpl` → `.claude/settings.json`
- `.conjure-version`

The `cmd_update --apply` MERGE-04 passthrough test verifies that `.conjure-version` and `settings.json` are overwritten directly from upstream templates without invoking `git merge-file`.

---

## No Analog Found

All four files have close analogs in the existing codebase. No files require fallback to RESEARCH.md patterns alone.

---

## Metadata

**Analog search scope:** `cli/`, `lib/`, `scripts/`, `tests/`, `.github/workflows/`, `templates/`
**Files read:** `lib/mutate.sh`, `cli/conjure`, `scripts/audit-setup.sh`, `scripts/init-project.sh`, `scripts/preflight.sh`, `tests/run.sh`, `tests/lib/sandbox.sh`, `.github/workflows/ci.yml`, `.planning/research/ARCHITECTURE.md`, `.planning/phases/09-3-way-merge/09-CONTEXT.md`
**Pattern extraction date:** 2026-05-25
