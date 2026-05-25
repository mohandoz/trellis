---
phase: 12-org-overlay
reviewed: 2026-05-26T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - scripts/init-overlay.sh
  - scripts/refresh-overlay.sh
  - cli/conjure
  - scripts/audit-setup.sh
  - tests/run.sh
findings:
  critical: 3
  warning: 6
  info: 4
  total: 13
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-05-26T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the org overlay implementation: two worker scripts (`init-overlay.sh`, `refresh-overlay.sh`), the unified CLI (`cli/conjure`), the audit health-checker (`audit-setup.sh`), and the regression test suite (`tests/run.sh`). The overlay mechanics are well-structured — backup-before-mutate, dry-run enforcement, and marker-based drift detection are correctly wired. However, three blockers were found: a temp-directory leak on unexpected failure paths, a git option-injection vector via overlay URLs, and a silent arithmetic crash in `audit-setup.sh`. Six additional warnings cover dead code, a broken `help` subcommand, unchecked arithmetic, and test cleanup gaps.

## Critical Issues

### CR-01: CLONE_TMP not cleaned up on rev-parse or copy failure (temp dir leak)

**File:** `scripts/init-overlay.sh:48`, `scripts/refresh-overlay.sh:62`

**Issue:** Both scripts create `CLONE_TMP` with `mktemp -d` but register no `trap ... EXIT` to clean it up. The explicit `rm -rf "$CLONE_TMP"` at lines 56/70 only runs on the happy path. Under `set -euo pipefail`, any unexpected failure after clone — such as `git rev-parse HEAD` returning non-zero on a corrupt clone, or a `mutate_cp` call inside the `while` loop encountering a permission error — causes the script to exit immediately without executing the cleanup. The temp directory is leaked for the remainder of the OS session.

**Fix:** Add an EXIT trap immediately after `mktemp -d` in both scripts, and remove the redundant unconditional `rm -rf` at the bottom (the trap handles it):

```bash
CLONE_TMP="$(mktemp -d)"
trap 'rm -rf "$CLONE_TMP"' EXIT

git clone --depth 1 "$OVERLAY_URL" "$CLONE_TMP" 2>/dev/null \
  || { echo "✗ git clone failed for: $DISPLAY_URL" >&2; exit 1; }
# ... rest of script
# No explicit rm -rf needed — trap fires on all exits
```

---

### CR-02: Git option injection via overlay URL (--upload-pack and flag injection)

**File:** `scripts/init-overlay.sh:45`, `scripts/refresh-overlay.sh:59`, `scripts/audit-setup.sh:156`

**Issue:** The overlay URL is passed directly to `git clone` and `git ls-remote` without a `--` separator:

```bash
git clone --depth 1 "$OVERLAY_URL" "$CLONE_TMP"
git ls-remote "$OVERLAY_URL" HEAD
```

If an attacker can write to the `.conjure-org-overlay` marker file (e.g., via a compromised repo, a path-traversal write, or a social-engineering scenario where the URL is supplied on the command line), a URL beginning with `--` would be interpreted as a git flag. More critically, a URL of the form `--upload-pack=malicious-command` causes git to execute an arbitrary command on the local machine during both `clone` and `ls-remote`. This is a documented git command-injection vector.

**Fix:** Use `--` before the URL argument in all three call sites to prevent git from interpreting URL content as flags:

```bash
# init-overlay.sh and refresh-overlay.sh:
git clone --depth 1 -- "$OVERLAY_URL" "$CLONE_TMP" 2>/dev/null \
  || { echo "✗ git clone failed for: $DISPLAY_URL" >&2; exit 1; }

# audit-setup.sh:
UPSTREAM_SHA="$(git ls-remote -- "$OVERLAY_URL" HEAD 2>/dev/null | awk '{print $1}')" || true
```

Additionally, consider validating that `OVERLAY_URL` begins with a recognized scheme (`https://`, `git@`, `ssh://`, `file://`) before executing any git command against it.

---

### CR-03: Arithmetic crash when graphify file cannot be stat'd

**File:** `scripts/audit-setup.sh:116`

**Issue:** The graphify freshness check contains nested command substitutions inside an arithmetic expression:

```bash
AGE_DAYS=$(( ($(date +%s) - $(stat -f %m graphify-out/graph.json 2>/dev/null || stat -c %Y graphify-out/graph.json)) / 86400 ))
```

If both `stat -f` (BSD/macOS) and `stat -c` (GNU/Linux) fail — for example because the file is on an NFS mount that becomes unavailable between the `-f` check and execution — the inner `$()` expands to an empty string. The expression becomes `$(( (date_val - ) / 86400 ))`, which is a bash arithmetic syntax error and exits the script non-zero under `set -uo pipefail`. Because `audit-setup.sh` uses `set -uo pipefail` (not `set -euo pipefail`), the actual behavior depends on whether arithmetic errors abort the script — in bash 4+, a failed arithmetic substitution is fatal under `pipefail`. This would cause the audit to crash rather than reporting a warning.

**Fix:** Guard the stat result with a default:

```bash
if [ -f graphify-out/graph.json ]; then
  _mtime="$(stat -f %m graphify-out/graph.json 2>/dev/null \
             || stat -c %Y graphify-out/graph.json 2>/dev/null \
             || echo 0)"
  AGE_DAYS=$(( ( $(date +%s) - _mtime ) / 86400 ))
  if [ "$AGE_DAYS" -gt 7 ]; then warn "graphify graph is $AGE_DAYS days old — run: graphify . --update"
  else ok "graphify graph: $AGE_DAYS days old"
  fi
fi
```

---

## Warnings

### WR-01: Dead prereq check — `lib/mutate.sh` existence test is unreachable

**File:** `scripts/init-overlay.sh:33-36`, `scripts/refresh-overlay.sh:28-31`

**Issue:** Both scripts `source "$CONJURE_HOME/lib/mutate.sh"` at line 17/16 under `set -euo pipefail`. If the file is absent, `source` fails and the script exits immediately. The `-f` check at lines 33–36 is therefore unreachable on the failure path: if `source` succeeded, the file exists; if it failed, the script already exited. The defensive error message (`✗ lib/mutate.sh not found`) will never be printed.

**Fix:** Move the `-f` check before the `source` call so it can actually fire and print a helpful message:

```bash
if [ ! -f "$CONJURE_HOME/lib/mutate.sh" ]; then
  echo "✗ lib/mutate.sh not found — check CONJURE_HOME ($CONJURE_HOME)" >&2
  exit 2
fi
source "$CONJURE_HOME/lib/mutate.sh"
```

---

### WR-02: `conjure help <subcommand>` silently produces no output for hyphenated subcommands

**File:** `cli/conjure:316`

**Issue:** `cmd_help` uses `sed -n "/^cmd_$1()/,/^}/p"` to find the function body. Subcommand names use hyphens (`refresh-graph`, `refresh-overlay`, `install-mcp`) but their bash function names use underscores (`cmd_refresh_graph`, `cmd_refresh_overlay`, `cmd_install_mcp`). Running `conjure help refresh-overlay` searches for `/^cmd_refresh-overlay()/` which never matches. The command silently outputs nothing, giving no indication to the user that help is unavailable.

**Fix:** Translate hyphens to underscores when building the sed pattern:

```bash
cmd_help() {
  if [ -n "${1:-}" ]; then
    local fn_name
    fn_name="$(printf '%s' "$1" | tr '-' '_')"
    sed -n "/^cmd_${fn_name}()/,/^}/p" "$0" | head -20
  else
    usage
  fi
}
```

---

### WR-03: `cmd_update` `--check` mode iterates `find` output without quoting (word-splitting)

**File:** `cli/conjure:186-193`

**Issue:** The `--check` diff loop uses `for f in $(find ...)` (acknowledged with a `shellcheck disable=SC2046` comment). This pattern breaks on filenames containing spaces, tabs, or glob characters. While skill directory names in practice do not contain spaces, this pattern is fragile and will silently skip or miscount affected files if a template ever has a space in its path. The `shellcheck disable` comment suppresses the warning without fixing the root cause.

**Fix:** Replace with a `while read -r` loop using process substitution, consistent with the pattern used correctly elsewhere in the codebase:

```bash
local diff_count=0
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

### WR-04: `audit-setup.sh` missing `set -e` — silent failure in overlay drift check

**File:** `scripts/audit-setup.sh:6`

**Issue:** `audit-setup.sh` declares `set -uo pipefail` but omits `set -e`. This means command failures inside the script body are not fatal unless they appear in pipelines (`pipefail`) or reference unset variables (`-u`). In the overlay section specifically, if `grep` or `cut` fail while parsing the marker file (e.g., a malformed marker with no `url=` line), `OVERLAY_URL` is set to an empty string silently. The subsequent `git ls-remote "" HEAD` call fails, and the `|| true` suppression causes the drift check to be silently skipped without any warning to the user.

**Fix:** Either add `set -e` to the shebang line options (`set -euo pipefail`), or guard the marker parsing with explicit emptiness checks:

```bash
OVERLAY_URL="$(grep '^url=' "$OVERLAY_MARKER" | cut -d= -f2-)"
if [ -z "$OVERLAY_URL" ]; then
  warn "[overlay] marker missing url= field — run conjure init --overlay again"
else
  # proceed with git ls-remote
fi
```

---

### WR-05: `tests/run.sh` — `MKTPL_DIR` and `SKILL_DIR` have no EXIT trap; leak on failure

**File:** `tests/run.sh:764`, `tests/run.sh:898`

**Issue:** `MKTPL_DIR` and `SKILL_DIR` are created with `mktemp -d` but no `trap ... EXIT` is registered for either. The explicit `rm -rf` at lines 888 and 1071 only execute if all intervening assertions succeed. If any bash command within those sections fails under `set -uo pipefail` — for example, if `git -C "$MKTPL_DIR" commit` returns non-zero, or a `cp` fails — the script exits before cleanup, leaving the temp directories on disk. These directories contain git repos and credentials (`user.email`), which are minor but real hygiene issues.

**Fix:** Register cleanup traps immediately after each `mktemp -d` call:

```bash
MKTPL_DIR="$(mktemp -d)"
trap 'rm -rf "$MKTPL_DIR"' EXIT
# ... all MKTPL tests ...
rm -rf "$MKTPL_DIR"
trap - EXIT

SKILL_DIR="$(mktemp -d)"
trap 'rm -rf "$SKILL_DIR"' EXIT
# ... all SKILL tests ...
rm -rf "$SKILL_DIR"
trap - EXIT
```

---

### WR-06: `audit-setup.sh` COST_TMP trap overwritten when both `--cost` and `--retire-list` are active

**File:** `scripts/audit-setup.sh:207`, `scripts/audit-setup.sh:253`

**Issue:** When both `CONJURE_COST=1` and `CONJURE_RETIRE=1` are set, two `trap ... EXIT` calls are made. The second trap at line 253 (`trap 'rm -f "${COST_TMP:-}"' EXIT`) overwrites the first (`trap 'rm -f "$COST_TMP"' EXIT`). While both reference `COST_TMP`, the first uses an unquoted variable reference that will hold the correct value at trap-set time, and the second uses `${COST_TMP:-}` which is safe but unnecessary. The behavioral consequence is negligible, but registering multiple EXIT traps without chaining them via a wrapper function is fragile. If a future developer adds a third block with its own trap, it will silently suppress cleanup from the first two.

**Fix:** Use a single consolidated cleanup function registered once:

```bash
_audit_cleanup() { rm -f "${COST_TMP:-}"; }
trap '_audit_cleanup' EXIT
```

Or use `trap 'cmd1; cmd2' EXIT` to chain both cleanup actions.

---

## Info

### IN-01: Redundant `lib/mutate.sh` check in `init-overlay.sh` exit-code contract comment

**File:** `scripts/init-overlay.sh:9-12`

**Issue:** The exit code contract in the header comment lists exit code 2 as "hard prerequisite failure (git not installed, lib/mutate.sh missing)". Since the `lib/mutate.sh` missing check is dead code (WR-01), the contract comment is misleading. It implies the script can exit 2 with a helpful message for a missing mutate.sh, which it cannot.

**Fix:** After fixing WR-01, the comment will be accurate. No separate action needed beyond WR-01.

---

### IN-02: `git clone` stderr suppressed unconditionally — failure diagnosis opaque

**File:** `scripts/init-overlay.sh:45`, `scripts/refresh-overlay.sh:59`

**Issue:** Both scripts redirect `git clone` stderr to `/dev/null` (`2>/dev/null`). This means network errors, authentication failures, and permission errors all produce the same generic message: `✗ git clone failed for: ...`. In an org context where users may encounter authentication issues with private overlay repos, the absence of the actual git error makes debugging substantially harder.

**Fix:** Consider capturing stderr and printing it only on failure:

```bash
CLONE_ERR="$(mktemp)"
git clone --depth 1 -- "$OVERLAY_URL" "$CLONE_TMP" 2>"$CLONE_ERR" \
  || { echo "✗ git clone failed for: $DISPLAY_URL" >&2
       cat "$CLONE_ERR" >&2
       rm -f "$CLONE_ERR"
       exit 1; }
rm -f "$CLONE_ERR"
```

---

### IN-03: `tests/run.sh` — `FM_DIR` temp dirs have no EXIT trap

**File:** `tests/run.sh:338`, `tests/run.sh:352`, `tests/run.sh:365`

**Issue:** Three `FM_DIR` temp directories are created in the failure-mode section with no EXIT trap. The `rm -rf "$FM_DIR"` calls at lines 348, 360, and 375 are explicit cleanup, but under `set -uo pipefail`, a failure in the commands between `mktemp` and `rm -rf` would leave temp dirs behind. The risk is lower here than for WR-05 (these dirs contain only synthetic test content), but the pattern is inconsistent with the rest of the test suite.

**Fix:** Register and clear traps for each FM_DIR block, consistent with MERGE_DIR handling.

---

### IN-04: OVLY test missing coverage for `init-overlay.sh` with empty URL

**File:** `tests/run.sh:1078-1242`

**Issue:** The OVLY test section tests `init-overlay.sh` with a valid `file://` URL, a valid URL with `DRY_RUN=1`, and verifies the marker. There is no test for the empty-URL case (i.e., calling `init-overlay.sh` with no argument). The script does handle this correctly (exits 1 with a usage message), but it is not regression-tested. A future refactor that changes argument parsing could silently break the empty-URL guard.

**Fix:** Add a test assertion:

```bash
# OVLY empty-URL guard
EMPTY_RC=0
CONJURE_HOME="$CONJURE_HOME" bash "$CONJURE_HOME/scripts/init-overlay.sh" \
  "" "$OVLY_TARGET" 2>/dev/null || EMPTY_RC=$?
if [ "$EMPTY_RC" -eq 1 ]; then
  pass "init-overlay exits 1 for empty URL"
else
  fail "init-overlay did not exit 1 for empty URL — got rc=$EMPTY_RC"
fi
```

---

_Reviewed: 2026-05-26T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
