---
phase: 10-marketplace-publish
reviewed: 2026-05-25T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .claude-plugin/marketplace.json
  - .claude-plugin/plugin.json
  - .github/workflows/ci.yml
  - cli/conjure
  - scripts/publish-plugin.sh
  - tests/run.sh
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-05-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 10 adds the `conjure publish` subcommand, the `scripts/publish-plugin.sh` worker, two manifest files, version-consistency CI gates, and regression tests in `tests/run.sh`. The implementation is coherent and the core publish flow is correct. However, one critical bug causes misleading output when `--dry-run` and `--submit` are combined, four warnings cover missing guards, silent CI suppression, temp-dir leak, and a mismatched section header, and three info items address naming gaps and coverage omissions.

---

## Critical Issues

### CR-01: `--dry-run --submit` prints checklist but writes no file, silently misleading user

**File:** `scripts/publish-plugin.sh:111-145`

**Issue:** When invoked with both `--dry-run` and `--submit`, `mutate_write` correctly skips writing `submit-entry.json` (dry-run semantics), but the checklist block executes unconditionally within the `CONJURE_SUBMIT=1` branch. The checklist instructs the user to paste the contents of `.claude-plugin/submit-entry.json` into the web form — a file that was never written. The user sees a complete-looking checklist for a file that does not exist on disk.

```bash
if [ "$CONJURE_SUBMIT" = "1" ]; then
  # ... json built, mutate_write called (skipped in dry-run) ...
  mutate_write "$PLUGIN_DIR/submit-entry.json" "$SUBMIT_JSON"
  echo "✓ submit-entry.json written"           # prints even in dry-run

  echo "▸ conjure publish --submit checklist:"
  echo "  [ ] Paste the contents of .claude-plugin/submit-entry.json ..."  # file absent!
fi
```

**Fix:** Guard the checklist and `"✓ submit-entry.json written"` message behind a `DRY_RUN` check:

```bash
if [ "$CONJURE_SUBMIT" = "1" ]; then
  # ... build SUBMIT_JSON ...
  mutate_write "$PLUGIN_DIR/submit-entry.json" "$SUBMIT_JSON"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would write submit-entry.json (skipped)"
  else
    echo "✓ submit-entry.json written"
    echo ""
    echo "▸ conjure publish --submit checklist:"
    echo "  [ ] Run: claude plugin validate . && claude plugin validate .claude-plugin/plugin.json"
    echo "  [ ] Commit marketplace.json, plugin.json, and submit-entry.json"
    echo "  [ ] Push branch and create a release tag"
    echo "  [ ] Re-run 'conjure publish' after tagging to update SHA to tag commit"
    echo "  [ ] Visit: https://claude.ai/settings/plugins/submit"
    echo "  [ ] Paste the contents of .claude-plugin/submit-entry.json into the submission form"
    echo "  NOTE: Direct PRs to anthropics/claude-plugins-community are auto-closed."
    echo "        Use the web form at the URL above."
  fi
fi
```

---

## Warnings

### WR-01: `publish-plugin.sh` missing existence guard for `plugin.json`

**File:** `scripts/publish-plugin.sh:57-82`

**Issue:** The script explicitly checks that `marketplace.json` exists before proceeding (lines 57-60) and exits 2 with a clear diagnostic. No equivalent guard exists for `plugin.json`. If `plugin.json` is absent, the script reaches line 79 (`jq empty "$PLUGIN_DIR/plugin.json"`), which emits a cryptic `jq` error ("No such file or directory") and exits via `set -euo pipefail` with no actionable message. The exit code at that point would be 1 (from `jq`), not the documented 2 for "hard prerequisite failure."

**Fix:** Add a symmetric guard directly after the `marketplace.json` check:

```bash
if [ ! -f "$PLUGIN_DIR/plugin.json" ]; then
  echo "✗ $PLUGIN_DIR/plugin.json not found" >&2
  exit 2
fi
```

---

### WR-02: CI `Audit script smoke` step silently swallows all audit failures

**File:** `.github/workflows/ci.yml:64`

**Issue:** The step `bash scripts/audit-setup.sh . || true` runs the audit against the Conjure repo itself but unconditionally succeeds via `|| true`. Any audit finding (size cap breach, hook misconfiguration, missing CLAUDE.md, etc.) against the live codebase is invisible to CI. This gate provides no signal value and could mask regressions.

```yaml
- name: Audit script smoke
  run: bash scripts/audit-setup.sh . || true   # failures silently suppressed
```

**Fix:** Remove `|| true` and either accept exit code 1 (warnings) as non-blocking or add an explicit threshold. At minimum accept rc ≤ 2 (the documented "expected" range) to block on crashes while tolerating warnings:

```yaml
- name: Audit script smoke
  run: |
    bash scripts/audit-setup.sh . ; rc=$?
    [ "$rc" -le 2 ] || { echo "audit-setup.sh crashed (rc=$rc)"; exit 1; }
```

---

### WR-03: `MKTPL_DIR` and `SUBMIT_DIR` temp directories not protected by `EXIT` traps

**File:** `tests/run.sh:764,850,885,888`

**Issue:** The MKTPL sandbox (`MKTPL_DIR`) and submit sandbox (`SUBMIT_DIR`) are each created with `mktemp -d` but never registered in an `EXIT` trap. Cleanup relies solely on unconditional `rm -rf` calls at lines 885 and 888. If the test suite exits early (e.g., a signal, a `set -euo pipefail` triggered by an unexpected command failure between sandbox creation and cleanup), both temp directories leak. The existing fixture loops correctly use `trap 'rm -rf "$SANDBOX_DIR"' EXIT` + `trap - EXIT`; MKTPL/SUBMIT blocks omit this discipline entirely.

**Fix:** Wrap each sandbox pair in a trap block consistent with the existing pattern:

```bash
MKTPL_DIR="$(mktemp -d)"
trap 'rm -rf "$MKTPL_DIR"' EXIT
# ... all MKTPL-01 and MKTPL-02 tests ...
rm -rf "$MKTPL_DIR"
trap - EXIT

SUBMIT_DIR="$(mktemp -d)"
trap 'rm -rf "$SUBMIT_DIR"' EXIT
# ... MKTPL-04 tests ...
rm -rf "$SUBMIT_DIR"
trap - EXIT
```

---

### WR-04: JSON validity tests silently pass when `jq` is absent from the host

**File:** `tests/run.sh:37-43`

**Issue:** The JSON validity loop (which covers `.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`, and template files) is guarded by `if command -v jq`. When `jq` is absent, the block is skipped and no test is registered — neither a pass nor a fail. Because `PASS` and `FAIL` counters are not updated, the suite exit code is unaffected. A developer running the suite locally without `jq` would see the suite "pass" while the manifest files were never validated. Given that `jq` is a documented hard dependency and the CI step installs it explicitly, the correct behavior when `jq` is absent is a hard failure.

**Fix:** Replace the silent skip with a hard fail:

```bash
if ! command -v jq >/dev/null 2>&1; then
  fail "jq not installed — JSON validation skipped (required dependency missing)"
else
  while IFS= read -r json; do
    if jq empty "$json" >/dev/null 2>&1; then pass "json valid: $json"
    else fail "json INVALID: $json"
    fi
  done < <(find templates .claude-plugin lib -name '*.json' 2>/dev/null)
fi
```

---

## Info

### IN-01: Test section header claims "MKTPL-01 through MKTPL-04" but MKTPL-03 is absent

**File:** `tests/run.sh:758`

**Issue:** The section echo reads `"▸ Marketplace publish tests (MKTPL-01 through MKTPL-04)"`. MKTPL-03 (schema validation via `claude plugin validate`) was intentionally implemented as a CI-only gate in `.github/workflows/ci.yml` and has no corresponding entry in `tests/run.sh`. The header is therefore inaccurate and creates confusion when reading test output or matching test IDs to requirements.

**Fix:** Update the header to reflect actual coverage:

```bash
echo "▸ Marketplace publish tests (MKTPL-01, MKTPL-02, MKTPL-04 — MKTPL-03 is CI-only)"
```

---

### IN-02: `submit-entry.json` is not gitignored; committing it between publish runs leaks stale SHA

**File:** `.gitignore`

**Issue:** `.claude-plugin/submit-entry.json` is generated by `conjure publish --submit` and contains the HEAD SHA at time of generation. The `--submit` checklist instructs the user to commit this file alongside `marketplace.json` and `plugin.json`. However, `submit-entry.json` is not in `.gitignore`, and the file contains a SHA that will become stale on the next publish. There is no enforcement preventing the file from being committed prematurely or at the wrong point in the workflow. A stale `submit-entry.json` submitted to the plugin marketplace would reference the wrong commit.

**Fix:** Either add `submit-entry.json` to `.gitignore` (if it should always be generated fresh, never committed) or add a note in the checklist explicitly stating it must be regenerated immediately before submission, not recycled from a prior run. The current checklist note to "re-run conjure publish after tagging" partially addresses this but is easy to miss.

---

### IN-03: `cmd_migrate` dry-run comparison uses unquoted RHS in `[ "$dryrun" = 0 ]`

**File:** `cli/conjure:127`

**Issue:** The backup guard reads `[ "$dryrun" = 0 ]` where `0` is unquoted. While functionally correct (bash string comparison works with numeric literals here), this is a shellcheck-detectable pattern (SC2053 in some versions) and is inconsistent with how `DRY_RUN` is tested elsewhere in the codebase (`[ "${DRY_RUN:-0}" = "1" ]` with quoted RHS). It is harmless but degrades consistency.

**Fix:**
```bash
[ "$dryrun" = "0" ] && cp -R "$target/.claude" "$backup"
```

---

_Reviewed: 2026-05-25T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
