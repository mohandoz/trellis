---
phase: 02-dry-run-enforcement-chokepoint
reviewed: 2026-05-24T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - cli/conjure
  - compliance/gdpr/apply.sh
  - compliance/hipaa/apply.sh
  - compliance/pci/apply.sh
  - compliance/soc2/apply.sh
  - lib/mutate.sh
  - profiles/data-science/apply.sh
  - profiles/go-gin/apply.sh
  - profiles/java-spring/apply.sh
  - profiles/monorepo/apply.sh
  - profiles/node-nest/apply.sh
  - profiles/polyglot/apply.sh
  - profiles/python-fastapi/apply.sh
  - profiles/rust-axum/apply.sh
  - profiles/ts-next/apply.sh
  - scripts/init-project.sh
  - tests/run.sh
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-24
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

This phase delivers `lib/mutate.sh` as the central dry-run enforcement chokepoint, threads `DRY_RUN` through `cli/conjure` → `scripts/init-project.sh` → all profile and compliance `apply.sh` scripts, and adds a regression test suite in `tests/run.sh`. The core library is correct and the subprocess env-var threading pattern works. However, two classes of mutation escape the chokepoint entirely (`chmod` calls in `compliance/hipaa/apply.sh` and `profiles/java-spring/apply.sh`), the `cmd_migrate` subcommand has no `--dry-run` support at its CLI entry point, and several defensive coding gaps exist in fragment-file handling and loop iteration.

---

## Critical Issues

### CR-01: `chmod` calls bypass the `mutate_*` chokepoint and are untracked

**File:** `compliance/hipaa/apply.sh:19`, `profiles/java-spring/apply.sh:22`

**Issue:** Both scripts issue `chmod +x` using an ad-hoc inline guard rather than routing through a `mutate_*` function. This means:

1. The `chmod` is not recorded in `CONJURE_DRY_MUTATION_COUNT`, so `mutate_summary` undercounts mutations.
2. Any future `mutate_chmod` auditing, logging, or policy enforcement added to `lib/mutate.sh` will silently miss these sites.
3. The two scripts are inconsistent with each other: `hipaa/apply.sh` suppresses errors with `2>/dev/null`; `java-spring/apply.sh` does not — a failed `chmod` in the java-spring path surfaces on stderr with no indication of whether it is fatal.

The `lib/mutate.sh` design contract (see header comment) states that all mutations must go through the library. These are out-of-band mutations.

**Fix:** Add a `mutate_chmod` function to `lib/mutate.sh`:

```bash
# mutate_chmod <file> <mode>
mutate_chmod() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would chmod $2 $1"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  chmod "$2" "$1"
}
```

Then replace both ad-hoc guards:

```bash
# compliance/hipaa/apply.sh line 19 — replace with:
mutate_chmod "$TARGET/.claude/hooks/pre-commit-phi-scan.sh" +x

# profiles/java-spring/apply.sh line 22 — replace with:
mutate_chmod "$TARGET/.claude/hooks/post-edit-format.sh" +x
```

---

### CR-02: `conjure migrate` has no `--dry-run` flag — the backup always runs in live mode

**File:** `cli/conjure:92`

**Issue:** `cmd_migrate` parses positional arguments only (`source`, `target`, `dryrun`). When a user invokes `conjure migrate from-claude /some/project` directly, `dryrun` defaults to `0` and there is no way to pass `--dry-run` at the CLI layer. The `cp -R` backup on line 107 executes unconditionally in live mode.

More concretely: line 107 reads `[ "$dryrun" = 0 ] && cp -R "$target/.claude" "$backup"`, which means the backup fires in live mode. A user who wants to preview what a migration would do cannot do so — the only dry-run path into `cmd_migrate` is through `cmd_init --dry-run` (which hard-codes the source as `from-claude`). Migrations for `from-cursor`, `from-aider`, `from-continue`, and `from-copilot` are completely unreachable in dry-run mode.

**Fix:** Add `--dry-run` parsing to `cmd_migrate` and expose it in the usage line:

```bash
cmd_migrate() {
  local source="" target="$(pwd)" dryrun=0
  while [ $# -gt 0 ]; do
    case "$1" in
      from-claude|from-cursor|from-aider|from-continue|from-copilot|from-windsurf)
        source="$1" ;;
      --dry-run) dryrun=1 ;;
      *)         target="$1" ;;
    esac
    shift
  done
  [ -z "$source" ] && { echo "Usage: conjure migrate <source> [--dry-run] [target]"; return 1; }
  # ... rest of function unchanged
```

---

## Warnings

### WR-01: `gdpr`, `pci`, and `soc2` compliance scripts do not guard against missing fragment files

**File:** `compliance/gdpr/apply.sh:7-9`, `compliance/pci/apply.sh:7-9`, `compliance/soc2/apply.sh:7-9`

**Issue:** These three scripts check that `$TARGET/CLAUDE.md` exists but do not check whether `$PROFILE_DIR/CLAUDE.md.fragment` exists before calling `cat`. In contrast, `compliance/hipaa/apply.sh:9` and all nine profile `apply.sh` scripts correctly guard with `[ -f "$PROFILE_DIR/CLAUDE.md.fragment" ]`.

All three scripts use `set -uo pipefail` without `-e`. A missing fragment file causes `$(cat "$PROFILE_DIR/CLAUDE.md.fragment")` to fail silently (no `-e`), passing an empty string to `mutate_write`, which then appends a blank line to `CLAUDE.md`. This is a silent data-corruption scenario — no error message, no non-zero exit, just an empty append.

**Fix:** Add the fragment-existence guard matching the HIPAA pattern:

```bash
# compliance/gdpr/apply.sh  (same fix applies to pci and soc2)
if [ -f "$TARGET/CLAUDE.md" ] && [ -f "$PROFILE_DIR/CLAUDE.md.fragment" ]; then
  if ! grep -q "<!-- compliance:gdpr -->" "$TARGET/CLAUDE.md"; then
    mutate_write "$TARGET/CLAUDE.md" "$(cat "$PROFILE_DIR/CLAUDE.md.fragment")" "--append"
  fi
fi
```

---

### WR-02: `for f in $(find ...)` in `cmd_update` is unsafe for paths with spaces

**File:** `cli/conjure:144`

**Issue:** Word splitting on the output of `find` will silently corrupt any SKILL.md path that contains a space. All other loops in the codebase (`tests/run.sh` throughout) correctly use `while IFS= read -r ... < <(find ...)`.

```bash
# Current — unsafe:
for f in $(find "$CONJURE_HOME/templates/skills" -name SKILL.md); do
```

**Fix:**

```bash
while IFS= read -r f; do
  local rel="${f#$CONJURE_HOME/templates/}"
  local proj="$target/.claude/${rel%/SKILL.md}/SKILL.md"
  if [ -f "$proj" ] && ! diff -q "$f" "$proj" >/dev/null 2>&1; then
    echo "  ~ ${rel%/SKILL.md}/SKILL.md (changed upstream)"
    diff_count=$((diff_count+1))
  fi
done < <(find "$CONJURE_HOME/templates/skills" -name SKILL.md)
```

---

### WR-03: Profile failure in `cmd_init` is silently swallowed

**File:** `cli/conjure:82`

**Issue:** When a profile's `apply.sh` exits non-zero (as `profiles/monorepo/apply.sh` does on line 19 when no monorepo directories are detected), `cmd_init` has no error handling around the subprocess call. With `set -uo pipefail` but no `-e`, the non-zero exit from `bash ... apply.sh` is silently ignored and execution continues to `mutate_write` and `mutate_summary`. The user receives the `✓ Scaffold complete` message even though the requested profile was not applied.

The `monorepo` profile prints `⚠ no monorepo dirs detected` before exiting, so the warning is visible in stdout — but there is no indication that the overall `init` failed.

**Fix:** Capture and check the profile exit code:

```bash
if [ -n "$profile" ] && [ -d "$CONJURE_HOME/profiles/$profile" ]; then
  echo "▸ Applying profile: $profile"
  if ! CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" bash "$CONJURE_HOME/profiles/$profile/apply.sh" "$target"; then
    echo "✗ Profile $profile failed — aborting init"
    return 1
  fi
fi
```

---

### WR-04: `mutate_write` does not ensure the destination directory exists

**File:** `lib/mutate.sh:50-63`

**Issue:** `mutate_write` calls `printf ... > "$dest"` or `printf ... >> "$dest"` without verifying that the parent directory of `$dest` exists. If a caller invokes `mutate_write` for a path whose parent directory has not yet been created (or whose `mutate_mkdir` was skipped — e.g., because of a glob that matched no files), the `printf` redirect fails silently in live mode (the error goes to stderr) and creates neither the directory nor the file. With `set -uo pipefail` but no `-e`, callers may not notice.

Example scenario: in `scripts/init-project.sh`, if the `mutate_mkdir ".claude/skills"` dry-run path increments the counter but an early `mutate_cp` somehow resolves to a path outside `.claude/`, a subsequent `mutate_write` could target a non-existent path.

**Fix:**

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
  mkdir -p "$(dirname "$dest")"   # ensure parent exists
  if [ "$mode" = "--append" ]; then
    printf '%s\n' "$content" >> "$dest"
  else
    printf '%s\n' "$content" > "$dest"
  fi
}
```

---

## Info

### IN-01: `CONJURE_DRY_MUTATION_COUNT` summary in the CLI process undercounts mutations

**File:** `cli/conjure:86-87`

**Issue:** `cmd_init` sources `lib/mutate.sh` (line 65) and calls `mutate_summary` (line 87). The counter in the CLI process only accumulates mutations issued directly within `cmd_init` — currently one `mutate_write` call (line 86). The far larger set of mutations performed inside `scripts/init-project.sh` and any profile `apply.sh` run as separate bash subprocesses; their counters are isolated and never flow back to the CLI process.

As a result the CLI's own `mutate_summary` will always print `[dry-run] 1 mutations skipped`, regardless of how many files would actually be created. The subprocess summaries (from `init-project.sh` and the profile script) do print correct counts to stdout, so the D-05 regression test passes, but a user reading only the last summary line will see a misleading count.

This is not causing incorrect behavior (no live mutations escape in dry-run mode) but is misleading output.

**Fix (minimal):** Either suppress the CLI-level `mutate_summary` call (since it adds no information beyond the subprocess summaries) or aggregate the count by reading it from a temp file written by each subprocess.

---

### IN-02: Skill-frontmatter description-length check uses `wc -c` (bytes) instead of character count

**File:** `tests/run.sh:55-56`

**Issue:** The test pipeline is:

```bash
desc_len=$(echo "$desc_line" | sed '...' | wc -c | tr -d ' ')
if [ "$desc_len" -lt 30 ]; then fail "description too short ($desc_len chars): $skill"; fi
```

`echo` adds a trailing newline before `wc -c`, so the effective threshold is 29 printable bytes, not 30. For ASCII-only content this is a trivial off-by-one. For descriptions containing multibyte UTF-8 characters the byte count exceeds the character count, making the test pass for strings that are actually shorter than 30 characters when measured in Unicode code points.

**Fix:** Use `wc -m` (character count) and strip the `echo`-added newline:

```bash
desc_len=$(printf '%s' "$(echo "$desc_line" | sed 's/^description: //;s/^"//;s/"$//')" | wc -m | tr -d ' ')
```

---

_Reviewed: 2026-05-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
