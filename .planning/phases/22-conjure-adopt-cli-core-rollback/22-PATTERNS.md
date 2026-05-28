# Phase 22: `conjure adopt` CLI Core + Rollback - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 5 (1 new script, 1 modified CLI, 1 new runtime JSON contract, 1 new fixture, 1 modified test block)
**Analogs found:** 5 / 5 (every new file has a strong in-repo analog — this phase is orchestration, not invention)

> All line numbers below are from the live source read this session. The planner should copy these patterns *exactly* — POSIX bash 3.2+, `exit 2` (never `exit 1`), all target mutations through `lib/mutate.sh`, inline shellcheck directives.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/adopt.sh` (NEW) | worker / pipeline orchestrator | batch + event-driven (signal traps) + transform | `scripts/resolve.sh` (multi-step worker + TTY/exit-2) + `scripts/init-project.sh` (lib-sourcing scaffold) | exact (composite) |
| `cli/conjure` :: `cmd_adopt` (MODIFY) | controller / dispatcher | request-response (parse flags → env → exec) | `cli/conjure` `cmd_resolve` (lines 176-190) + `cmd_audit` (lines 144-160) | exact |
| `.conjure-adopt-state` schema (NEW JSON contract) | model / state record | CRUD (jq read-modify-write, atomic temp+mv) | `adopt-manifest.schema.json` (draft-07 shape) + `.snapshot-meta.json` (lib/snapshot.sh lines 48-54) | role-match |
| synthetic `restructure_steps[]` manifest fixture (NEW) | test fixture | data (hand-authored JSON) | `tests/run.sh` Pattern-7 sample JSON (lines 2270-2312) + `adopt-manifest.schema.json` | role-match |
| Phase 22 block in `tests/run.sh` (MODIFY/APPEND) | test | request-response (run subprocess, assert) | Phase 21 block (`tests/run.sh` lines 1691-2358) + `tests/lib/sandbox.sh` | exact |

## Pattern Assignments

### `cli/conjure` :: `cmd_adopt` (controller, request-response)

**Analog:** `cli/conjure` `cmd_resolve` (lines 176-190), `cmd_audit` (lines 144-160). The invariant: `cli/conjure` parses flags, sets env vars, execs `scripts/*.sh`. **Zero business logic in the CLI.**

**Flag-parse + env-var-pass pattern** (canonical thin wrapper, `cmd_resolve` lines 176-190):
```bash
cmd_resolve() {
  local target dryrun
  target="$(pwd)"
  dryrun=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)   dryrun=1 ;;
      --help|-h)   echo "Usage: conjure resolve [--dry-run] [target]"; return 0 ;;
      *)           target="$1" ;;
    esac
    shift
  done
  CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" \
    bash "$CONJURE_HOME/scripts/resolve.sh" "$target"
}
```

**Multi-env-var pass pattern** (`cmd_audit` lines 156-159 — mirror this for the `CONJURE_ADOPT_*` contract; note the `cmd_preflight || return 1` gate that sibling commands run before exec):
```bash
  cmd_preflight || return 1
  CONJURE_HOME="$CONJURE_HOME" CONJURE_COST="$do_cost" CONJURE_EXACT="$do_exact" \
    CONJURE_RETIRE="$do_retire" \
    bash "$CONJURE_HOME/scripts/audit-setup.sh" "$target"
```

**Value-flag (`--apply-step <id>`) parse pattern** (an arg that consumes the next token — copy from `cmd_publish_skill` line 432, which uses `--to`):
```bash
      --to)        shift; target_repo="${1:-}" ;;
```
So `--apply-step` becomes: `--apply-step) shift; apply_step="${1:-}" ;;`

**Dispatch router entry** (bottom `case`, `cli/conjure` lines 460-476 — add the new line alongside `resolve)`):
```bash
case "${1:-help}" in
  init)            shift; cmd_init "$@"            ;;
  ...
  resolve)         shift; cmd_resolve "$@"         ;;
  # ADD:  adopt)   shift; cmd_adopt "$@"           ;;
  ...
  *)               echo "Unknown command: $1"; usage; exit 1 ;;
esac
```

**`usage()` entry** (add a line in the `cat <<EOF` block, `cli/conjure` lines 32-47, alongside `conjure resolve` at line 39). Note: `usage()` uses `exit 1` for unknown *command* (line 475) — that is the existing CLI dispatch convention and is distinct from the `exit 2` hard-failure convention inside the worker scripts.

---

### `scripts/adopt.sh` (worker, batch + event-driven + transform)

This file is a **composite** of three existing worker patterns. No single analog covers it; copy each section from its closest source.

**Analog A — `scripts/resolve.sh` (full file, 91 lines):** header + lib sourcing + `mktemp`/`trap` cleanup + non-TTY exit-2 guard + interactive prompt loop + `mutate_summary`.
**Analog B — `scripts/init-project.sh` (lines 1-23):** `set -euo pipefail`, `KIT=...`, `source lib/mutate.sh`, idempotent scaffold (the subprocess adopt calls).
**Analog C — `lib/snapshot.sh` + `lib/log.sh`:** the auto-logging integration (set `RESTRUCTURE_LOG_PATH` once → snapshot/inventory self-log).

**Header + lib sourcing + exit-2-on-source-failure** (mirror `scripts/resolve.sh` lines 1-17 — note `set -uo pipefail`, NOT `set -e`, and the `|| { echo ...; exit 2; }` source guard):
```bash
#!/usr/bin/env bash
# scripts/resolve.sh — interactive sidecar walker for `conjure resolve`.
set -uo pipefail

CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${1:-$(pwd)}"

# SC1090: dynamic path — shellcheck can't follow, suppress with directive.
# shellcheck source=/dev/null
source "$CONJURE_HOME/lib/mutate.sh" || { echo "resolve.sh: cannot source lib/mutate.sh" >&2; exit 2; }
```
adopt.sh sources five libs the same way (`mutate.sh`, `caps.sh`, `log.sh`, `snapshot.sh`, `inventory.sh`); each gets its own `# shellcheck source=/dev/null` + `|| { ...; exit 2; }` guard. **Sourcing order matters:** `mutate.sh` first (everything depends on it), then `caps.sh`/`log.sh`, then `snapshot.sh`/`inventory.sh` (which require mutate+log already sourced — see their header comments).

**`mktemp` + `trap ... EXIT` cleanup** (resolve.sh lines 20-21 — adopt.sh reuses this for the dry-run temp manifest dir per D-11):
```bash
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT
```
For the dry-run manifest (D-11), use `mktemp -d` (a dir) outside the target: `tmp_manifest_dir="$(mktemp -d)"`.

**Signal trap for INT/TERM → exit 2** (SAFE-05; resolve.sh only traps EXIT-cleanup, so this is *new* logic — but the `exit 2` discipline is the established convention seen in `log_fail`, lib/log.sh lines 47-51):
```bash
# lib/log.sh log_fail — the exit-2 convention to mirror:
log_fail() {
  local message="$1"
  log_step "FAIL" "${message}"
  exit 2
}
```
adopt.sh adds: `trap '...flush note...; exit 2' INT TERM` (graceful interrupts). **Critical (Pitfall 4):** SIGKILL is untrappable — the trap handles INT/TERM only; durability (write state BEFORE each mutating step) is what makes the `kill -9` recovery test pass.

**Auto-logging integration — set `RESTRUCTURE_LOG_PATH` once** (lib/snapshot.sh lines 58-61 + lib/inventory.sh lines 416-418 both gate `log_step` on `RESTRUCTURE_LOG_PATH` being set; `log_init` sets it — lib/log.sh lines 16-27):
```bash
# lib/snapshot.sh lines 58-61 — snapshot self-logs IFF RESTRUCTURE_LOG_PATH set:
  if [ -n "${RESTRUCTURE_LOG_PATH:-}" ]; then
    log_step SNAPSHOT "created at ${snap_dir}"
  fi
```
So adopt.sh calls `log_init "$TARGET"` early (Step 0.5); snapshot + inventory then log themselves (SAFE-07). Do NOT call snapshot before log_init or the SNAPSHOT entry is lost.

**Dirty-tree precondition gate** (NEW logic — uses `git status --porcelain`, the contract-stable form per Pitfall 5; the `exit 2` + `--force` pattern is established):
```bash
# git status --porcelain: empty = clean (exit code irrelevant); catches tracked-modified AND untracked.
# dirty && !force → exit 2 (never exit 1). dirty && force → proceed + log_step WARN (SAFE-06).
```
Reference signature: `snapshot_create` already captures `git_head`/`git_stash_list` (lib/snapshot.sh lines 41-54), so SAFE-06 capture is done — only the user-facing WARN remains (D-15).

**Subprocess invocation — scaffold (ADOPT-04)** (mirror how `cli/conjure` calls init-project.sh at line 84, passing `CONJURE_HOME`/`DRY_RUN` through):
```bash
CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" bash "$CONJURE_HOME/scripts/init-project.sh" "$mode" "$target"
```
adopt.sh calls: `CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$DRY_RUN" bash "$CONJURE_HOME/scripts/init-project.sh" existing "$TARGET"`. init-project.sh is idempotent — every write is `[ ! -f ]`/`[ ! -d ]` guarded (init-project.sh lines 32-39, 50-56, 75-80). It uses `set -euo pipefail` and `exit 1` on **bad usage only** (line 17) — that is a usage error, not a runtime failure.

**Subprocess invocation — audit (ADOPT-05)** (mirror `cmd_audit` exec line 157-159; **capture rc, do NOT abort** — audit surfaces violations, doesn't gate):
```bash
# audit-setup.sh exit contract (audit-setup.sh lines 296-298): 0=pass, 1=warnings, 2=errors.
[ "$FAIL" -gt 0 ] && exit 2
[ "$WARN" -gt 0 ] && exit 1
exit 0
```
adopt.sh: `audit_rc=0; bash "$CONJURE_HOME/scripts/audit-setup.sh" "$TARGET" || audit_rc=$?` — capture, log, continue. (`set -e` is NOT used in these workers, so a non-zero subprocess won't abort; with `set -uo pipefail` you still must capture rc explicitly via `|| rc=$?`.)

**Cross-platform sha256 helper** (SAFE-02/SAFE-04 — copy the exact pattern from `lib/mutate.sh` lines 113-123, also used in `cli/conjure` lines 224-228):
```bash
# lib/mutate.sh lines 113-118:
  if command -v sha256sum >/dev/null 2>&1; then
    src_hash="$(sha256sum "${src}" | cut -d' ' -f1)"
    dest_hash="$(sha256sum "${dest}" | cut -d' ' -f1)"
  elif command -v shasum >/dev/null 2>&1; then
    src_hash="$(shasum -a 256 "${src}" | cut -d' ' -f1)"
    dest_hash="$(shasum -a 256 "${dest}" | cut -d' ' -f1)"
```

**Line-count helper** (ADOPT-06 report, avoid Pitfall 6 off-by-one — use the redirect form, exactly as `audit-setup.sh` line 29 and `inventory.sh` line 289):
```bash
LINES=$(wc -l < CLAUDE.md | tr -d ' ')
```

**Recovery prompt — non-TTY exit-2 guard + interactive loop** (mirror `scripts/resolve.sh` lines 32-80; D-13/D-14):
```bash
# resolve.sh lines 32-37 — non-interactive guard (fires only when state present):
if ! { [ -t 0 ] || [ "${CONJURE_FORCE_INTERACTIVE:-0}" = "1" ]; }; then
  echo "conjure resolve: stdin is not a TTY — interactive mode required" >&2
  exit 2
fi
# resolve.sh lines 52-80 — prompt loop with re-prompt on unknown (no default; empty re-prompts):
  while true; do
    read -r -p "  [k]eep / [a]pply / [e]dit / [s]kip: " choice
    case "$choice" in
      k|keep)  mutate_rm "$sidecar_path"; echo "  kept (sidecar removed)"; break ;;
      a|apply) content="$(cat "$sidecar_path")"; mutate_write "$current_file" "$content"; ...; break ;;
      s|skip)  echo "  skipped"; break ;;
      *)       echo "  Unknown choice; please enter k, a, e, or s" ;;   # no break → re-prompt
    esac
  done
```
adopt's prompt is `[r]ollback / [c]ontinue / [s]tart-fresh` — D-13 says read from `/dev/tty` (`read -r -p "..." choice < /dev/tty`) rather than resolve's fd-3 stdin trick (adopt has a single prompt, no file list to read concurrently). `CONJURE_FORCE_INTERACTIVE=1` is the established test escape hatch (resolve.sh line 34).

**End-of-script summary** (resolve.sh line 90 — always call `mutate_summary` last; it prints the dry-run mutation count):
```bash
mutate_summary
```

**Anti-patterns (from RESEARCH.md, confirmed against source):**
- Do NOT route `snapshot_create` through `mutate_cp` — snapshot uses raw `cp -a` deliberately (lib/snapshot.sh lines 32-38) so DRY_RUN doesn't suppress the backup.
- Do NOT write the manifest with `printf >`/heredoc — use `inventory_emit_manifest` (lib/inventory.sh line 413 routes through `mutate_write`).
- Do NOT rely on the lib's built-in DRY_RUN→`/tmp/adopt-manifest-dryrun.json` redirect (lib/inventory.sh lines 409-411 — fixed path, violates D-11). adopt.sh passes an explicit `mktemp -d` path; per D-10/A4, the read-only manifest may be written with DRY_RUN=0 for that one call.
- Do NOT use `exit 1` for hard failures — `exit 2` (matches `log_fail`, dirty-tree refusal, non-TTY recovery, missing-snapshot rollback).

---

### `.conjure-adopt-state` schema (model, CRUD — atomic temp+mv)

**Analog:** `adopt-manifest.schema.json` (draft-07 style) for the shape; `.snapshot-meta.json` build pattern (lib/snapshot.sh lines 48-54) for the injection-safe `jq -cn` write.

**Injection-safe JSON construction** (lib/snapshot.sh lines 48-54 — `jq -cn` with `--arg`/`--argjson`, NEVER shell string interpolation into JSON; copy this for every state write):
```bash
  meta_content="$(jq -cn \
    --arg created_at "${meta_ts}" \
    --arg target "$(cd "${target}" && pwd)" \
    --arg git_head "${git_head}" \
    --arg git_stash_list "${git_stash}" \
    '{created_at: $created_at, target: $target, git_head: $git_head, git_stash_list: $git_stash_list}')"
  mutate_write "${snap_dir}/.snapshot-meta.json" "${meta_content}"
```

**Larger-array JSON construction** (lib/inventory.sh lines 364-403 — `jq -cn --slurpfile` for `files[]`/`restructure_steps[]`-style arrays, building nested `summary` object). This is the template for the `created[]`/`mutated[]` arrays in `.conjure-adopt-state`.

**Atomic write (temp+mv — NEW, resolves Pitfall 2 read-modify-write truncation):** No exact in-repo `jq ... > tmp && mv` precedent — the SUMMARY.md/RESEARCH.md recommendation is:
```bash
# First write:  jq -n '...' > "${STATE_PATH}.tmp.$$" && mv "${STATE_PATH}.tmp.$$" "$STATE_PATH"
# Update:       jq '<filter>' "$STATE_PATH" > "${STATE_PATH}.tmp.$$" && mv "${STATE_PATH}.tmp.$$" "$STATE_PATH"
```
Keep the temp in the **same dir** (`${STATE_PATH}.tmp.$$`) so `mv` is a same-filesystem atomic rename (A2). Schema sketch (from RESEARCH.md lines 475-491; mirror `adopt-manifest.schema.json` draft-07 style if a schema file is added): `schema_version`, `started_at`, `target`, `snapshot_path`, `current_step`, `steps{}` (per-step `pending`/`started`/`completed`), `created[]` (scaffolded harness paths only — D-02), `mutated[{path, before, after}]`. **Open question (planner decides):** file form (`.conjure-adopt-state` + sibling staging dir) vs directory form (`.conjure-adopt-state/state.json` + `.conjure-adopt-state/staging/`). D-07's literal path `.conjure-adopt-state/staging/<file>` implies directory form — RESEARCH.md "leans directory."

**`restructure_steps[]` op shape** (`adopt-manifest.schema.json` line 192-196 — currently `items: {}` / always empty at inventory time; Phase 22 makes it read+write). Op object per D-05/D-07: `{ id, op: "write"|"archive"|"extract", dest, src: ".conjure-adopt-state/staging/<file>", status: "proposed"|"applied" }`.

---

### Synthetic `restructure_steps[]` manifest fixture (test fixture)

**Analog:** `tests/run.sh` Pattern-7 sample JSON (lines 2270-2312) — a heredoc-authored manifest validated with `jq -e`. The fixture is hand-authored JSON with a populated `restructure_steps[]` (one `write` op + one `archive` op per D-08), conforming to `adopt-manifest.schema.json`.

**Validation idiom** (tests/run.sh lines 2257, 2313 — `jq empty` for parse, `jq -e '...'` for key presence):
```bash
if jq empty "$CONJURE_HOME/adopt-manifest.schema.json" >/dev/null 2>&1; then
  pass "adopt-manifest.schema.json: valid JSON (SC-4)"
...
if jq -e '.schema_version and .summary and .files' "$P21_SCHEMA_SAMPLE" >/dev/null 2>&1; then
```
**Placement (RESEARCH.md line 217-220):** under `tests/fixtures/`. Per-repo artifacts (`.conjure-adopt-state`, backups, `RESTRUCTURE-LOG.md`, live `adopt-manifest.json`) are written into the *target*, never committed in fixtures.

---

### Phase 22 block in `tests/run.sh` (test, request-response)

**Analog:** Phase 21 block (`tests/run.sh` lines 1691-2358) + `tests/lib/sandbox.sh`. Mirror its exact structure.

**Assertion helpers** (defined at top of run.sh, lines 14-16 — use these; do NOT invent new ones):
```bash
t() { TESTS+=("$1"); }
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
```

**Section header + lib-present guard** (Phase 21 lines 1696-1703 — every section prints a `▸ Phase NN — ...` header and guards on file existence so the suite fails gracefully before the file is built):
```bash
echo
echo "▸ Phase 21 — lib/caps.sh (SC-5)"

P21_CAPS_OK=0
if ! source "$CONJURE_HOME/lib/caps.sh" 2>/dev/null; then
  fail "lib/caps.sh not found — Wave 1 must create it first (SC-5)"
else
  P21_CAPS_OK=1
  ...
fi
```
Phase 22 sections: `▸ Phase 22 — adopt.sh dry-run (ADOPT-02/criterion 1)`, `... live (ADOPT-01/04/05/06)`, `... dirty-tree (ADOPT-03/SAFE-06)`, `... rollback (SAFE-02)`, `... recovery (SAFE-05)`, `... apply-step (D-05/D-08)`, etc. Each tags the requirement ID in the message (Phase 21 convention).

**Sandbox + live-run isolation** (Phase 21 snapshot test lines 1820-1846 — `mktemp -d` target, `cp -r fixture/. target/`, run in a subshell sourcing the libs, `trap 'rm -rf ...' EXIT` then `trap - EXIT` after, assert on outputs). For full CLI runs use `sandbox_setup` (tests/lib/sandbox.sh lines 46-63) which sets `SANDBOX_DIR`, copies the fixture, isolates `HOME`/`PATH`:
```bash
# tests/run.sh line 328 etc. — the standard pattern:
sandbox_setup "$fx"          # → SANDBOX_DIR set, fixture copied, EXIT-trap registered
```
**Trap caveat (tests/run.sh lines 248-249, 1777, 1846):** bash `trap ... EXIT` is NOT additive — each section sets its own EXIT trap then resets with `trap - EXIT` before the next. `sandbox_setup` registers its own EXIT trap (sandbox.sh line 49), so a manual trap set before `sandbox_setup` would be overwritten. Follow the Phase 21 set/reset discipline.

**DRY_RUN sub-shell run + grep assertion** (Phase 21 log test lines 1730-1745 — run the unit in a `bash -c` subprocess with env vars, capture stdout, grep for the expected marker):
```bash
  P21_LOG_DRY_OUT="$(
    DRY_RUN=1 RESTRUCTURE_LOG_PATH="/tmp/conjure-p21-log-dryrun-$$" \
    CONJURE_HOME="$CONJURE_HOME" \
    bash -c '
      source "$CONJURE_HOME/lib/mutate.sh"
      source "$CONJURE_HOME/lib/log.sh"
      ...
    ' 2>&1
  )"
  if printf '%s\n' "$P21_LOG_DRY_OUT" | grep -q "dry-run"; then
    pass "log.sh DRY_RUN=1: output contains dry-run indicator ..."
```
For ADOPT-02 zero-writes: after a dry-run, assert `git status --porcelain "$sb"` empty AND `find "$sb" -name adopt-manifest.json` empty (Pitfall 1 / criterion-1 verification). New test harnesses needed (no existing analog): git-init'd sandbox for the dirty-tree test (criterion 3), and a background-launch + `kill -9` for the SIGKILL recovery test (criterion 5 — the non-TTY `exit 2` + "last completed: snapshot" assertion is the simplest reliable form).

**Suite tail** (tests/run.sh lines 2364-2368 — the suite prints `PASS: $PASS  FAIL: $FAIL`; non-zero `FAIL` fails the suite. Append the Phase 22 block *before* line 2361's stub cleanup, or extend the existing block — do not add a new summary).

## Shared Patterns

### Mutation chokepoint (apply to ALL target writes in adopt.sh)
**Source:** `lib/mutate.sh` (full file, 147 lines)
**Apply to:** `scripts/adopt.sh` — every filesystem write to the *target* (scaffold writes, `--apply-step` ops, state... except state uses raw `jq>tmp+mv` for atomicity, and snapshot uses raw `cp -a`).
Functions + signatures (all DRY_RUN-aware, all increment `CONJURE_DRY_MUTATION_COUNT`):
```bash
mutate_mkdir   <dir>
mutate_cp      <src> <dest>                # cp -r for dirs, plain cp for files
mutate_write   <dest> <content> [--append] # printf '%s' (no trailing newline); pass content as ARG, never pipe
mutate_rm      <path>                       # rm -f (no -r)
mutate_archive <src_abs> <archive_root>    # cp -a → sha256 verify → rm → .archive-ledger; rejects relative/'..' src (lines 96-102)
mutate_summary                              # call at end; prints "[dry-run] N mutations skipped"
```
**`--apply-step` op dispatch (D-05/D-08):** `write` → `mutate_write "$dest" "$(cat "$src")"` (src under staging/); `archive` → `mutate_archive "$abs_src" "$archive_root"`; `extract` = write+archive composed. `mutate_archive` requires an absolute, traversal-free src (lines 96-102) — validate before calling.

### Logging (SAFE-07 — apply to every pipeline step)
**Source:** `lib/log.sh` (full file, 51 lines)
**Apply to:** every step of `scripts/adopt.sh`.
```bash
log_init <target_dir>      # writes RESTRUCTURE-LOG.md header (mutate_write replace), SETS RESTRUCTURE_LOG_PATH
log_step <PHASE> <message> # appends "[ts] [PHASE] msg\n" via mutate_write --append (per-step durability)
log_fail <message>         # appends FAIL entry, then exit 2  ← the hard-failure convention
```
Call `log_init "$TARGET"` at Step 0.5 (after the precondition gate passes) so snapshot (lib/snapshot.sh 58-61) and inventory (lib/inventory.sh 416-418) auto-log. Append per-step, never batched.

### Snapshot/rollback primitives (SAFE-01/SAFE-02 — D-01 builds on these)
**Source:** `lib/snapshot.sh` (full file, 100 lines)
**Apply to:** `scripts/adopt.sh` Step 1 + `rollback_path()`.
```bash
snapshot_create <target> <backup_root>   # → sets CONJURE_SNAPSHOT_PATH; raw cp -a (NOT mutate_cp); DRY_RUN prints would-be path; writes .snapshot-meta.json (git_head/git_stash_list)
snapshot_rollback <snapshot_path> <target>  # whole-tree cp -a snapshot/. target/; validates path exists (return 1 if not); auto-logs ROLLBACK. Does NOT delete created[] — that is adopt.sh's job (D-01 step 2).
snapshot_list <backup_root>              # ls -1t newest-first. NOTE: takes backup_root, NOT target.
```
**D-01 rollback adds on top:** after `snapshot_rollback`, loop `created[]` → `mutate_rm`; then verify `sha256(p)==before` for each `mutated[]`; then `log_step ROLLBACK`; then `rm -f` the state file (keep snapshot/archive/log — D-04).

### Inventory (ADOPT-01 — Step 2, read-only)
**Source:** `lib/inventory.sh` (lines 137-235 scan, 242-428 emit)
**Apply to:** `scripts/adopt.sh` Step 2.
```bash
inventory_scan <target>                       # sets CONJURE_INVENTORY_ITEMS / _TOTAL_FOUND / _SCAN_CAPPED; read-only; 500-file cap; excludes .git/node_modules/.conjure-adopt-backups/.conjure-archive-*
inventory_emit_manifest <target> <output_path> # writes manifest via mutate_write; auto-logs INVENTORY. DRY_RUN=1 hardcodes /tmp/adopt-manifest-dryrun.json (Pitfall 1 — adopt.sh must override the path via D-11 mktemp).
```
Report metrics read back from the manifest with `jq -r '.summary.total_files'` etc. (RESEARCH.md report block lines 497-508).

### Caps (ADOPT-05/ADOPT-06 report)
**Source:** `lib/caps.sh` (full file, 11 lines)
```bash
CLAUDE_MD_CAP=100   SKILL_MD_CAP=200   AGENT_MD_CAP=80
```
Used for the CLAUDE.md line-count-delta-vs-cap report line and by the audit subprocess (audit-setup.sh sources caps.sh at line 10).

### shellcheck directive style (quality gate)
**Source:** inline directives across the libs.
- Dynamic `source`: `# shellcheck source=/dev/null` immediately above (resolve.sh line 16).
- `ls` for time-sort: `# shellcheck disable=SC2012` (snapshot.sh line 96).
- Read-both-sides-of-pipe: `# shellcheck disable=SC2094` (inventory.sh line 223).
- Subprocess source with known path: `# shellcheck source=lib/caps.sh` (audit-setup.sh line 9).
Match this inline style; `shellcheck scripts/adopt.sh cli/conjure` must be clean before the phase gate.

## No Analog Found

No file in this phase lacks an analog. The genuinely *new* logic (not a copy-paste of an existing function, but composed from existing patterns) is flagged for the planner:

| Logic | Closest Pattern | Why New |
|-------|-----------------|---------|
| `.conjure-adopt-state` atomic `jq>tmp+mv` write | `.snapshot-meta.json` `jq -cn` (snapshot.sh 48-54) | No in-repo read-modify-write-with-rename precedent; RESEARCH.md Pitfall 2 prescribes it |
| INT/TERM signal trap + write-state-before-step durability | `log_fail` exit-2 (log.sh 47-51); resolve.sh EXIT-trap (20-21) | No existing INT/TERM trap; SIGKILL durability is net-new (Pitfall 4) |
| SIGKILL recovery test harness (background-launch + `kill -9` + re-run) | Phase 21 sub-shell run pattern (run.sh 1730-1745) | No existing background-kill test in the suite |
| git-initialized sandbox for dirty-tree test | `sandbox_setup` (sandbox.sh 46-63) | sandbox_setup copies a fixture but does not `git init`; criterion 3 needs an untracked-file dirty tree |
| Snapshot self-copy guard (Pitfall 3) | inventory.sh already excludes `.conjure-adopt-backups` (lines 173-175); snapshot.sh does NOT | Open question: lib change vs ordering guard — planner decides + adds a two-consecutive-adopts regression test |

## Metadata

**Analog search scope:** `cli/`, `scripts/`, `lib/`, `tests/`, `tests/fixtures/`, repo-root JSON schemas
**Files scanned (read this session):** `cli/conjure`, `scripts/resolve.sh`, `scripts/init-project.sh`, `scripts/audit-setup.sh`, `lib/snapshot.sh`, `lib/inventory.sh`, `lib/log.sh`, `lib/mutate.sh`, `lib/caps.sh`, `tests/run.sh` (Phase 21 block + helpers + tail), `tests/lib/sandbox.sh`, `adopt-manifest.schema.json` — plus `22-CONTEXT.md` and `22-RESEARCH.md`
**Pattern extraction date:** 2026-05-28
