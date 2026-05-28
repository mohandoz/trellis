# Phase 21: Foundation Libs + Inventory - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 8 new/modified files
**Analogs found:** 7 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/caps.sh` | utility/config | transform | `lib/mutate.sh` (module init pattern) + `scripts/audit-setup.sh` (cap literal call sites) | role-match |
| `lib/log.sh` | utility | request-response | `lib/mutate.sh` (mutate_write, DRY_RUN guard, counter) + `lib/merge.sh` (sibling lib structure) | role-match |
| `lib/snapshot.sh` | utility | file-I/O | `lib/merge.sh` (mktemp + while IFS= read, module-level state) + `tests/lib/sandbox.sh` (cp -r isolation) | role-match |
| `lib/inventory.sh` | utility | batch | `lib/merge.sh` (mktemp + while IFS= read -r, find loop) + `scripts/audit-setup.sh` (wc -l, find, per-file checks) | role-match |
| `lib/mutate.sh` (add `mutate_archive`) | utility | file-I/O | `lib/mutate.sh` lines 31-45 (`mutate_cp` — copy primitive) + lines 67-77 (`mutate_rm` — remove primitive) | exact |
| `scripts/audit-setup.sh` (call-site change) | utility | request-response | `scripts/audit-setup.sh` lines 25-29, 53-54, 78 — the three inline cap literal sites | exact |
| `adopt-manifest.schema.json` | config | transform | `lib/prices.json` (JSON config file structure) | partial |
| `tests/fixtures/brownfield-simple/` + Phase 21 block in `tests/run.sh` | test | request-response | `tests/fixtures/ts-next/` (fixture structure) + `tests/run.sh` lines 254-294 (mutate_rm unit tests — sourced lib pattern) | exact |

---

## Pattern Assignments

### `lib/caps.sh` (utility/config, transform)

**Analog:** `lib/mutate.sh` (lines 1-17 — module header + state init) and `lib/merge.sh` (lines 1-16 — sibling lib header)

**Header / sourcing guard pattern** (`lib/mutate.sh` lines 1-17):
```bash
#!/usr/bin/env bash
# lib/mutate.sh — sourced mutation chokepoint for Conjure.
# Source this file; call mutate_mkdir, mutate_cp, mutate_write, mutate_rm, mutate_summary.
# Requires: DRY_RUN env var (0=live, 1=dry); set -u safe via ${DRY_RUN:-0}.
# POSIX bash 3.2+ compatible. No associative arrays, no mapfile, no local -n.

# Initialize dry-run mutation counter if not already set.
# Safe under set -u; idempotent on re-source.
CONJURE_DRY_MUTATION_COUNT="${CONJURE_DRY_MUTATION_COUNT:-0}"
```

**lib/caps.sh header must follow the same pattern — no shebang, no executable bit, sourced only:**
```bash
# lib/caps.sh — sourced cap constants for Conjure.
# Source this file; do not execute directly.
# Requires: lib/mutate.sh already sourced (for mutate_archive).
# POSIX bash 3.2+. No associative arrays, no mapfile, no local -n.

CLAUDE_MD_CAP=100
SKILL_MD_CAP=200
AGENT_MD_CAP=80
```

**Call-site where caps live today** (`scripts/audit-setup.sh` lines 25-29, 53-54, 78):
```bash
# Line 26 — CLAUDE.md cap literal:
if [ "$LINES" -le 100 ]; then ok "CLAUDE.md: $LINES lines (≤100)"
elif [ "$LINES" -le 200 ]; then warn ...
else err "CLAUDE.md: $LINES lines (HARD CAP exceeded — trim)"

# Line 54 — Skill cap literal:
if [ "$LINES" -gt 200 ]; then warn "Skill '$name': $LINES lines (>200)"; fi

# Line 78 — Agent cap literal:
if [ "$LINES" -gt 80 ]; then warn "Agent '$name': $LINES lines (>80)"; fi
```

---

### `lib/log.sh` (utility, request-response)

**Analog:** `lib/mutate.sh` lines 47-65 (`mutate_write`) + `lib/merge.sh` lines 1-16 (sibling lib structure)

**Sibling lib header pattern** (`lib/merge.sh` lines 1-16):
```bash
#!/usr/bin/env bash
# lib/merge.sh — 3-way merge for cmd_update --apply.
# Source this file; requires lib/mutate.sh already sourced and DRY_RUN set.
# POSIX bash 3.2+. No associative arrays, no mapfile, no local -n.
# Requires: CONJURE_HOME, DRY_RUN, and mutate_write/mutate_mkdir from lib/mutate.sh.

# Initialize conflict tracking state.
# Safe under set -u; idempotent on re-source.
CONJURE_MERGE_CONFLICT_COUNT="${CONJURE_MERGE_CONFLICT_COUNT:-0}"
CONJURE_MERGE_CONFLICT_FILES=""
```

**mutate_write core pattern** (`lib/mutate.sh` lines 47-65) — CRITICAL: `printf '%s'` has NO trailing newline, so log entries must include `\n` in their content string:
```bash
mutate_write() {
  local dest="$1"
  local content="$2"
  local mode="${3:-}"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would write $dest"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  if [ "$mode" = "--append" ]; then
    printf '%s' "$content" >> "$dest"
  else
    printf '%s' "$content" > "$dest"
  fi
}
```

**log_step must embed `\n` to avoid line-joining** (RESEARCH.md Pitfall 1):
```bash
log_step() {
  local phase="$1"
  local message="$2"
  local ts
  ts="$(date -u '+%Y-%m-%d %H:%M:%S')"
  local entry="[${ts}] [${phase}] ${message}
"
  mutate_write "${RESTRUCTURE_LOG_PATH}" "${entry}" --append
}
```

**Module-level state init pattern** (`lib/merge.sh` lines 13-15 — idempotent re-source):
```bash
CONJURE_MERGE_CONFLICT_COUNT="${CONJURE_MERGE_CONFLICT_COUNT:-0}"
CONJURE_MERGE_CONFLICT_FILES=""
```

---

### `lib/snapshot.sh` (utility, file-I/O)

**Analog:** `lib/merge.sh` (sibling lib structure) + `tests/lib/sandbox.sh` line 50 (`cp -r` isolation) + `scripts/audit-setup.sh` lines 116-122 (`stat` cross-platform)

**Sibling lib sourcing header** (`lib/merge.sh` lines 1-6):
```bash
#!/usr/bin/env bash
# lib/merge.sh — 3-way merge for cmd_update --apply.
# Source this file; requires lib/mutate.sh already sourced and DRY_RUN set.
# POSIX bash 3.2+. No associative arrays, no mapfile, no local -n.
# Requires: CONJURE_HOME, DRY_RUN, and mutate_write/mutate_mkdir from lib/mutate.sh.
```

**cp -r isolation pattern** (`tests/lib/sandbox.sh` line 50):
```bash
cp -r "$fixture_dir/." "$SANDBOX_DIR/"
```

**DRY_RUN guard pattern** (`lib/mutate.sh` lines 22-28 — copy for all mutate_* functions):
```bash
if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[dry-run] would mkdir $1"
  CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
  return 0
fi
```

**snapshot_create must use raw `cp -a`, NOT `mutate_cp`** — DRY_RUN on mutate_cp would suppress the backup entirely, removing the safety net. In dry-run mode: print would-be path, skip cp, set CONJURE_SNAPSHOT_PATH. In live mode: `cp -a target/. snap_dir/` unconditionally.

**UTC timestamp pattern** (`scripts/audit-setup.sh` line 119):
```bash
AGE_DAYS=$(( ( $(date +%s) - _mtime ) / 86400 ))
```
For snapshot naming: `date -u '+%Y%m%dT%H%M%SZ'` (POSIX, unambiguous Z-suffix per RESEARCH.md M-4).

---

### `lib/inventory.sh` (utility, batch)

**Analog:** `lib/merge.sh` lines 106-123 (mktemp + while IFS= read -r find loop) + `scripts/audit-setup.sh` lines 47-68 (per-file wc -l, find, POSIX skill loop)

**POSIX bash 3.2+ find loop — no process substitution** (`lib/merge.sh` lines 106-123):
```bash
local _merge_list_skills
_merge_list_skills="$(mktemp)"
find "$CONJURE_HOME/templates/skills" -name SKILL.md > "$_merge_list_skills"
while IFS= read -r tmpl_file; do
  rel="${tmpl_file#$CONJURE_HOME/templates/}"
  current="$target/.claude/$rel"
  base="$snap_dir/$rel"
  if [ -f "$current" ] && [ -f "$base" ]; then
    merge_file_3way "$current" "$base" "$tmpl_file" "$rel" "$pinned_ver" "$conjure_ver"
    _rc=$?
    if [ "$_rc" -eq 2 ]; then
      rm -f "$_merge_list_skills"
      return 2
    fi
  fi
done < "$_merge_list_skills"
rm -f "$_merge_list_skills"
```

**wc -l cap detection pattern** (`scripts/audit-setup.sh` lines 25, 53, 78):
```bash
LINES=$(wc -l < CLAUDE.md | tr -d ' ')
if [ "$LINES" -le 100 ]; then ...
```
`wc -l < "$path"` redirect form avoids filename noise in output (RESEARCH.md Don't Hand-Roll table).

**CONJURE_INVENTORY_ITEMS state pattern** — follow merge.sh's `CONJURE_MERGE_CONFLICT_FILES` newline-delimited accumulator (line 73):
```bash
CONJURE_MERGE_CONFLICT_FILES="${CONJURE_MERGE_CONFLICT_FILES:+$CONJURE_MERGE_CONFLICT_FILES }$sidecar_path"
```
For inventory: `CONJURE_INVENTORY_ITEMS` (newline-delimited file paths, written to mktemp, read back via `while IFS= read -r`).

**find exclusion pattern** (`scripts/audit-setup.sh` lines 48, 72, 98):
```bash
find .claude/skills -name SKILL.md
find .claude/agents -maxdepth 1 -name '*.md'
find .claude/hooks -maxdepth 1 -name '*.mjs'
```
For inventory: extend with `-not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/.conjure-adopt-backups/*'`.

---

### `lib/mutate.sh` — add `mutate_archive` function (file-I/O)

**Analog:** `lib/mutate.sh` lines 31-45 (`mutate_cp`) + lines 67-77 (`mutate_rm`) — combine copy + verify + remove into one primitive

**mutate_cp pattern** (`lib/mutate.sh` lines 31-45):
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

**mutate_rm pattern** (`lib/mutate.sh` lines 67-77):
```bash
mutate_rm() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would rm $1"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  rm -f "$1"
}
```

**mutate_archive must combine both, with sha256 verify between cp and rm** (D-13). DRY_RUN guard at the top (same as all siblings); single counter increment at the end in live mode. sha256 cross-platform pattern: `command -v sha256sum` first, fall back to `shasum -a 256`, abort if neither found. Ledger written via `printf '%s\t%s\t%s\t%s\n' ... >> "${archive_root}/.archive-ledger"` — not via `mutate_write` (ledger is infrastructure, not user content).

**Function must be inserted between `mutate_rm` and `mutate_summary`** to preserve the file's logical grouping.

---

### `scripts/audit-setup.sh` — call-site change only (utility, request-response)

**Analog:** `scripts/audit-setup.sh` itself — lines 1-9 (top-of-file source block), lines 25-29, 53-54, 78 (the three cap literal sites)

**Source block pattern at top of audit-setup.sh** (`scripts/audit-setup.sh` lines 1-9):
```bash
#!/usr/bin/env bash
# audit-setup.sh — health-check the .claude/ setup in a repo.
# Usage: bash audit-setup.sh [target-dir]
# Exit codes: 0 = pass, 1 = warnings, 2 = errors.

set -uo pipefail

TARGET="${1:-$(pwd)}"
cd "$TARGET" || { echo "✗ Cannot cd to target: $TARGET"; exit 2; }
```

**Add `source` call near top, after `set -uo pipefail` and before the first cap use (line 25):**
```bash
# AFTER (add near top of audit-setup.sh):
source "${CONJURE_HOME}/lib/caps.sh"
# Then replace literals:
if [ "$LINES" -le "${CLAUDE_MD_CAP}" ]; then ...     # was 100
if [ "$LINES" -gt "${SKILL_MD_CAP}" ]; then ...       # was 200
if [ "$LINES" -gt "${AGENT_MD_CAP}" ]; then ...       # was 80
```

**`CONJURE_HOME` is already set in the script** via `$(cd "$(dirname "$0")/.." && pwd)` in `tests/run.sh` line 6 when called from tests; audit-setup.sh must set it itself when called standalone (same pattern used in audit-setup.sh lines 180, 201 with `: "${CONJURE_HOME:=...}"`).

---

### `adopt-manifest.schema.json` (config, transform)

**Analog:** `lib/prices.json` (existing JSON config file in lib/) — partial analog for structure; no exact role match in codebase.

**JSON Schema draft-07 structure** — planner should use RESEARCH.md Pattern 7 (the finalized schema sample) as the primary reference since no JSON Schema file exists in the codebase yet. The schema validates: `schema_version`, `generated_at`, `summary.*` (including `scan_capped`, `total_found`, per-bucket counts), `files[]` (with `size_cap_exceeded`, NOT `cap_exceeded`), `size_cap_violations[]`, `harness_missing_layers`, `restructure_steps[]`.

**JSON validity check pattern** (`tests/run.sh` lines 67-74):
```bash
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r json; do
    if jq empty "$json" >/dev/null 2>&1; then pass "json valid: $json"
    else fail "json INVALID: $json"
    fi
  done < <(find templates .claude-plugin lib -name '*.json' 2>/dev/null)
fi
```

---

### `tests/fixtures/brownfield-simple/` + Phase 21 test block in `tests/run.sh` (test, request-response)

**Analog:** `tests/fixtures/ts-next/` (fixture structure: CLAUDE.md, docs/, EXPECT) + `tests/run.sh` lines 254-294 (sourced lib unit tests — the mutate_rm unit test block)

**Fixture directory structure** (`tests/fixtures/ts-next/`):
```
CLAUDE.md
docs/
EXPECT
package.json
```

**brownfield-simple fixture must contain** (per RESEARCH.md Validation Architecture):
```
tests/fixtures/brownfield-simple/
  CLAUDE.md                          # 15-line valid core doc
  .claude/skills/git/SKILL.md        # skill bucket
  .claude/agents/deploy.md           # agent bucket
  docs/README.md                     # reference-doc bucket
  .planning/21-PLAN.md               # planning-doc bucket
  symlink-target -> docs/README.md   # symlink skip test (test -L)
```

**Sourced lib unit test pattern** (`tests/run.sh` lines 254-294 — complete mutate_rm block):
```bash
echo
echo "▸ mutate_rm unit tests (INFRA-01)"

MUTATE_RM_TMPPATH="/tmp/conjure-test-mutate-rm-$$-dry"
MUTATE_RM_OUT="$(
  DRY_RUN=1 bash -c '
    source '"'"'lib/mutate.sh'"'"'
    CONJURE_DRY_MUTATION_COUNT=0
    mutate_rm "'"$MUTATE_RM_TMPPATH"'"
    printf "%s\n" "[count=$CONJURE_DRY_MUTATION_COUNT]"
  '
)"
if printf '%s\n' "$MUTATE_RM_OUT" | grep -q "would rm"; then
  pass "mutate_rm dry-run: output contains 'would rm' (INFRA-01)"
else
  fail "mutate_rm dry-run: output missing 'would rm' (INFRA-01)"
fi
if printf '%s\n' "$MUTATE_RM_OUT" | grep -q "\[count=1\]"; then
  pass "mutate_rm dry-run: CONJURE_DRY_MUTATION_COUNT incremented to 1 (INFRA-01)"
else
  fail "mutate_rm dry-run: counter not incremented — got: $MUTATE_RM_OUT (INFRA-01)"
fi

# Live mode — create a real temp file, call function, assert it is gone:
MUTATE_RM_LIVE="$(mktemp)"
source lib/mutate.sh
DRY_RUN=0 mutate_rm "$MUTATE_RM_LIVE"
if [ ! -f "$MUTATE_RM_LIVE" ]; then
  pass "mutate_rm live: file removed by rm -f (INFRA-01)"
else
  fail "mutate_rm live: file still present after mutate_rm (INFRA-01)"
fi
```

**Phase 21 test block must follow this exact pattern**: section header `echo "▸ Phase 21 — ..."`, then DRY_RUN=1 subshell tests (with counter verification), then live-mode tests using mktemp. Each test uses `pass`/`fail` helpers already defined at top of run.sh.

**Fixture audit loop pattern** (`tests/run.sh` lines 323-340) — existing [^_] glob skips `_broken`:
```bash
for fx in "$CONJURE_HOME/tests/fixtures"/[^_]*/; do
  prof=$(basename "$fx")
  sandbox_setup "$fx"
  trap 'rm -rf "$SANDBOX_DIR"' EXIT
  AUDIT_OUT="$(bash "$CONJURE_HOME/scripts/audit-setup.sh" "$SANDBOX_DIR" 2>&1)"
  AUDIT_RC=$?
  if [ "$AUDIT_RC" -eq 0 ]; then
    pass "fixture audit green: $prof"
  else
    fail "fixture audit non-green (rc=$AUDIT_RC): $prof"
  fi
  rm -rf "$SANDBOX_DIR"
  trap - EXIT
done
```
`brownfield-simple` will be picked up by this existing loop automatically — it must pass `audit-setup.sh` with exit 0 (all checks green).

---

## Shared Patterns

### DRY_RUN Guard
**Source:** `lib/mutate.sh` lines 22-28 (reproduced in every `mutate_*` function)
**Apply to:** `mutate_archive` in `lib/mutate.sh`; `log_step`/`log_init`/`log_fail` in `lib/log.sh` (via `mutate_write`); `inventory_emit_manifest` in `lib/inventory.sh` (via `mutate_write`)
```bash
if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[dry-run] would <action> $1"
  CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
  return 0
fi
```

### CONJURE_DRY_MUTATION_COUNT Increment
**Source:** `lib/mutate.sh` line 17 (init) and lines 25, 37, 57, 72 (increments)
**Apply to:** Every function that performs a mutation — `mutate_archive` in live mode also increments (after the rm, not the cp — the whole operation counts as one mutation).
```bash
CONJURE_DRY_MUTATION_COUNT="${CONJURE_DRY_MUTATION_COUNT:-0}"   # at module level, idempotent
CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))  # in each function
```

### POSIX bash 3.2+ mktemp + while IFS= read -r Loop
**Source:** `lib/merge.sh` lines 107-123 (three identical find loops)
**Apply to:** `lib/inventory.sh` `inventory_scan` (find *.md loop), `lib/inventory.sh` `inventory_classify` (CLAUDE.md link extraction), `lib/snapshot.sh` any file iteration
```bash
_list="$(mktemp)"
find "${target}" -name '*.md' \
  -not -path '*/.git/*' \
  -not -path '*/node_modules/*' \
  > "${_list}"
while IFS= read -r filepath; do
  :
done < "${_list}"
rm -f "${_list}"
```

### Module-Level State Init (Idempotent Re-Source)
**Source:** `lib/mutate.sh` line 17; `lib/merge.sh` lines 13-15
**Apply to:** All new lib files — `lib/log.sh`, `lib/snapshot.sh`, `lib/inventory.sh`
```bash
CONJURE_SOME_STATE="${CONJURE_SOME_STATE:-0}"
CONJURE_SOME_LIST=""
```

### printf for Output (No echo -e/-n)
**Source:** `lib/mutate.sh` lines 61-64 (`printf '%s'`); `lib/merge.sh` line 65 (`printf '%s'`)
**Apply to:** All lib files — use `printf '%s'` or `printf '%s\n'` never `echo -e` or `echo -n`
```bash
printf '%s' "$content" >> "$dest"   # no trailing newline (mutate_write style)
printf '%s\n' "$entry"              # with newline (log entry style)
```

### UTC Timestamp Generation
**Source:** `scripts/audit-setup.sh` line 257 (`date -v/-d` cross-platform); RESEARCH.md M-4
**Apply to:** `lib/snapshot.sh` snapshot directory naming; `lib/mutate.sh` `mutate_archive` ledger entry; `lib/log.sh` log entry timestamps
```bash
ts="$(date -u '+%Y%m%dT%H%M%SZ')"    # for dir names (compact)
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" # for JSON/log fields (ISO 8601)
```

### Cross-Platform sha256
**Source:** `scripts/audit-setup.sh` (no existing sha256 usage — this is new); RESEARCH.md Pitfall 4
**Apply to:** `lib/mutate.sh` `mutate_archive` D-13 verify step only
```bash
if command -v sha256sum >/dev/null 2>&1; then
  src_hash="$(sha256sum "${src}" | cut -d' ' -f1)"
  dest_hash="$(sha256sum "${dest}" | cut -d' ' -f1)"
else
  src_hash="$(shasum -a 256 "${src}" | cut -d' ' -f1)"
  dest_hash="$(shasum -a 256 "${dest}" | cut -d' ' -f1)"
fi
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `adopt-manifest.schema.json` | config | transform | No JSON Schema files exist in the codebase; `lib/prices.json` is a data file, not a schema. Planner must use RESEARCH.md Pattern 7 (finalized schema sample) and JSON Schema draft-07 conventions directly. |

---

## Critical Implementation Notes

**mutate_write trailing newline (RESEARCH.md Summary, Pitfall 1):**
`mutate_write` at `lib/mutate.sh` line 61 uses `printf '%s'` — NO trailing newline. Every `log_step` call must embed `\n` in the content string (literal newline or `\n`). Without it, consecutive `log_step` calls join their output on one line.

**snapshot_create must bypass mutate_cp (RESEARCH.md Summary, Anti-Patterns):**
`lib/snapshot.sh` `snapshot_create` uses raw `cp -a "$target/." "$snap_dir/"` — never `mutate_cp`. Routing through `mutate_cp` would suppress the backup under `DRY_RUN=1`, removing the only safety net. This is the deliberate exception to the "all writes funnel through lib/mutate.sh" invariant.

**Process substitution is banned (RESEARCH.md Pattern 4):**
`while ... done < <(cmd)` is bash 4+ only. `audit-setup.sh` uses it internally (lines 65, 79, 100) but new lib files must use `mktemp + while IFS= read -r ... done < "$tmpfile"; rm -f "$tmpfile"`.

**CONJURE_HOME resolution in audit-setup.sh:**
The `source "${CONJURE_HOME}/lib/caps.sh"` line requires `CONJURE_HOME` to be set before sourcing. `audit-setup.sh` does not set it at the top — it uses `: "${CONJURE_HOME:=...}"` lazily at lines 180 and 201. The caps source line must come after or alongside a `CONJURE_HOME` resolution. Safest: add `: "${CONJURE_HOME:="$(cd "$(dirname "$0")/.." && pwd)"}"` immediately before the `source` call.

---

## Metadata

**Analog search scope:** `lib/`, `scripts/`, `tests/`, `tests/lib/`, `tests/fixtures/ts-next/`
**Files scanned:** 5 source files fully read (lib/mutate.sh, lib/merge.sh, scripts/audit-setup.sh, tests/run.sh, tests/lib/sandbox.sh)
**Pattern extraction date:** 2026-05-28
