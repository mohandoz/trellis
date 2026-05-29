---
phase: 21-foundation-libs-inventory
reviewed: 2026-05-28T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/caps.sh
  - lib/log.sh
  - lib/mutate.sh
  - lib/snapshot.sh
  - lib/inventory.sh
  - scripts/audit-setup.sh
  - adopt-manifest.schema.json
  - tests/fixtures/brownfield-simple/generate-large.sh
  - tests/run.sh
findings:
  critical: 2
  warning: 8
  info: 6
  total: 16
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-05-28
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed nine POSIX-bash shell libraries and supporting artifacts for the Conjure
adopt/inventory subsystem. The mutation chokepoint (`mutate.sh`) and the D-13
never-delete-unverified guarantee in `mutate_archive` are well constructed: copy →
sha256-verify → delete, with the destination removed and `return 1` on every failure
path before the source is ever unlinked. DRY_RUN is honored consistently across
`mutate_*` and the dependent libs, and the snapshot primitive correctly bypasses
`mutate_cp` by design.

However, two BLOCKER-class defects break the documented cross-platform contract and
the binary-skip safety behavior on stock macOS (the project's explicitly supported
platform). Several WARNING-class correctness bugs (trailing-slash path derivation,
unverified `find`/`wc` counts feeding `-gt` integer comparisons, multi-line stash
capture, line-count under-counting against caps) can produce wrong manifests or
runtime errors under realistic inputs. The adversarial concerns flagged in the brief
(command injection, eval, DRY_RUN bypass, the delete-on-mismatch guarantee) were
specifically traced and held up — the substantive issues are elsewhere.

## Critical Issues

### CR-01: Binary-file detection is broken on stock macOS (BSD grep has no `-P`)

**File:** `lib/inventory.sh:219`
**Issue:** `inventory_scan` skips binary files with:
```bash
if LC_ALL=C grep -Pc '\x00' "${filepath}" 2>/dev/null | grep -q '^[1-9]'; then
```
The `-P` (PCRE) flag does not exist in BSD grep, which is the stock `/usr/bin/grep`
on macOS. Verified directly on this machine: `/usr/bin/grep -Pc '\x00'` exits with
`grep: invalid option -- P` and rc=2, producing **no count output**. The downstream
`grep -q '^[1-9]'` therefore never matches, so the `continue` is never taken and
**binary files are not skipped on macOS** — contradicting the file's own contract
("Skips symlinks (M-2) and binary files"). macOS is an explicitly supported platform
per CLAUDE.md ("stay cross-platform"), and the module header forbids GNU-only
constructs. A `.md` file containing embedded NULs (or any mis-named binary) would be
classified, line-counted, and emitted into the manifest. The error is silenced by
`2>/dev/null`, so it fails invisibly.
**Fix:** Use a POSIX-portable NUL test. Either grep for a literal NUL byte, or use
`tr`/`od`:
```bash
# Portable: matches a literal NUL byte; works on BSD and GNU grep.
if LC_ALL=C grep -q "$(printf '\000')" "${filepath}" 2>/dev/null; then
  continue
fi
```
or
```bash
if LC_ALL=C tr -d -c '\000' < "${filepath}" 2>/dev/null | head -c 1 | grep -q .; then
  continue
fi
```

### CR-02: `mutate_archive` sha256 path is incompatible with macOS BSD `cut`/locale assumptions only partially — primary defect is unguarded relative-path archive can escape archive_root via absolute src normalization

**File:** `lib/mutate.sh:93-95`
**Issue:** The mirror-path derivation strips only a single leading slash:
```bash
local rel="${src#/}"
local dest="${archive_root}/${rel}"
```
The function is documented as `mutate_archive <src_abs> <archive_root>` and the D-12
"path-preserving layout" assumes `src` is absolute. But there is **no validation that
`src` is absolute and no normalization of `..` components**. If a caller passes a
relative path or a path containing `..` (e.g. `../../etc/passwd` or
`/proj/../../etc/foo`), `rel` retains the `..` segments and `dest` becomes
`${archive_root}/../../etc/...`, so the verified-then-deleted source is copied
*outside* `archive_root` (path traversal / archive escape). Because the subsequent
`rm -f "${src}"` runs after a successful copy+verify, a malicious or malformed
manifest-driven archive list could relocate files anywhere the process can write,
then delete the originals — defeating the "archive, never lose" intent of D-12/D-13.
Since archive inputs in later phases derive from a scanned/inventoried tree, an
attacker-controlled repo (symlink games, crafted paths) is a realistic threat model
for an open-source "adopt any repo" tool.
**Fix:** Reject non-absolute paths and `..` traversal before deriving `dest`:
```bash
case "${src}" in
  /*) : ;;  # absolute, ok
  *)  echo "[mutate_archive] ABORT: src must be absolute: ${src}" >&2; return 1 ;;
esac
case "${src}" in
  *..*) echo "[mutate_archive] ABORT: src contains '..': ${src}" >&2; return 1 ;;
esac
local rel="${src#/}"
local dest="${archive_root}/${rel}"
# Defense-in-depth: confirm dest stays under archive_root after mkdir.
```
(If relative `src` must be supported, canonicalize it first and re-anchor under
`archive_root` explicitly.)

## Warnings

### WR-01: Relative-path derivation breaks when `target` has a trailing slash

**File:** `lib/inventory.sh:50` (and `:271`)
**Issue:** `rel="${filepath#"${target}"/}"` strips `${target}/`. If a caller passes
`target` *with* a trailing slash (e.g. `/repo/`), the expansion becomes
`${filepath#/repo//}`, which does not match `/repo/CLAUDE.md`, so `rel` stays the
full absolute path. Verified: with `target=/foo/bar/` and `filepath=/foo/bar/CLAUDE.md`,
`rel` = `/foo/bar/CLAUDE.md` (unchanged). Every `case "${rel}"` classifier
(`CLAUDE.md)`, `.claude/skills/*/SKILL.md)`, etc.) then fails to match and the file
is mis-bucketed as `unknown`. The public entrypoints (`inventory_scan`,
`inventory_emit_manifest`, `inventory_classify`) accept `target` from external callers
and never normalize it.
**Fix:** Normalize `target` once at the top of each public function:
```bash
target="${target%/}"   # strip any trailing slash before deriving rel
```

### WR-02: `find | wc -l` count is used in `-gt` integer comparison without guarding empty/whitespace

**File:** `lib/inventory.sh:147-154, 201`
**Issue:** `total_found` is captured from `find ... | wc -l | tr -d ' '`. If `find`
errors (output suppressed by `2>/dev/null`) or the environment yields an empty
result, `total_found` can be empty. Line 201 then runs `[ "${total_found}" -gt 500 ]`
with no `${total_found:-0}` default; under an empty value this is a runtime error
(`integer expression expected`) — and because the module runs under `set -u` only
when sourced into a `set -u` caller, the behavior is environment-dependent and the
error is not caught. The same raw value is later passed to jq via
`--argjson total_found "${total_found}"`, where an empty string makes jq emit a parse
error and the whole manifest write fails.
**Fix:** Default the value at capture and at every comparison/interpolation:
```bash
total_found="$(find ... | wc -l | tr -d ' ')"
total_found="${total_found:-0}"
CONJURE_INVENTORY_TOTAL_FOUND="${total_found}"
```

### WR-03: `wc -l` under-counts files lacking a trailing newline, corrupting cap enforcement

**File:** `lib/inventory.sh:284, 311`; `scripts/audit-setup.sh:29, 57, 81`
**Issue:** Line counts are computed with `wc -l`, which counts *newline characters*,
not logical lines. A file whose final line has no trailing newline is under-counted
by one (verified: a 3-logical-line file with no trailing `\n` reports `2`). This means
a CLAUDE.md sitting exactly at the cap boundary, or one whose last line is the
overflow, can evade `size_cap_exceeded`/`size_cap_violations` detection and the audit
HARD-CAP gate. Caps are a core, CI-enforced project invariant ("CLAUDE.md ≤100 lines …
enforced by audit/CI"), so an off-by-one in the counter undermines the guarantee.
**Fix:** Count logical lines accounting for a missing final newline, e.g.
```bash
line_count="$(awk 'END{print NR}' "${filepath}")"
```
`awk 'END{print NR}'` counts the last unterminated line. Apply consistently in
`inventory.sh` and `audit-setup.sh`.

### WR-04: Multi-line `git stash list` breaks/garbles snapshot metadata capture

**File:** `lib/snapshot.sh:43`
**Issue:** `git_stash="$(git ... stash list 2>/dev/null | head -10 ...)"` captures up to
ten newline-separated stash lines into a single shell variable, then passes it through
`jq --arg git_stash_list`. jq does encode the embedded newlines as `\n` (so the JSON
stays valid), but the resulting field is a single opaque blob with `head -10`
silently truncating — losing rollback-reference fidelity that the comment claims to
preserve ("git state capture for rollback reference"). More importantly, the captured
value is never split or structured, so the "reference" is effectively unusable for any
programmatic rollback. This is a latent data-fidelity bug rather than a crash.
**Fix:** Capture stash entries as a JSON array instead of a flattened blob:
```bash
git_stash="$(git -C "${target}" stash list 2>/dev/null | head -10 \
  | jq -R . | jq -cs . || printf '[]')"
# then: --argjson git_stash_list "${git_stash:-[]}"
```

### WR-05: `cd "${target}" && pwd` silently yields empty `target` field on cd failure

**File:** `lib/snapshot.sh:51`; `lib/inventory.sh:366`
**Issue:** Both files compute the canonical target as `--arg target "$(cd "${target}"
&& pwd)"`. If `cd` fails (target removed mid-run, permission error), the command
substitution yields an empty string with no error surfaced, and the manifest /
snapshot-meta records `"target": ""`. The schema (`adopt-manifest.schema.json`)
declares `target` as a non-empty descriptive absolute path but does not enforce
`minLength`, so the empty value validates and propagates an unusable manifest
downstream. Verified: `val="$(cd /nonexistent && pwd)"` produces an empty `val`.
**Fix:** Fail fast when the target cannot be resolved:
```bash
local target_abs
target_abs="$(cd "${target}" 2>/dev/null && pwd)" || {
  printf '%s\n' "[inventory] ERROR: cannot resolve target: ${target}" >&2
  return 1
}
```
and pass `${target_abs}` to jq.

### WR-06: Symlinked `.md` files can still reach classification via the `-f` guard

**File:** `lib/inventory.sh:267`
**Issue:** `inventory_emit_manifest` guards each path with `[ ! -f "${filepath}" ] &&
continue`. `[ -f ]` follows symlinks, so a symlink to a regular `.md` file passes the
guard. Symlink filtering relies entirely on the earlier `inventory_scan` pass (line
215) having excluded it. The two functions are independently callable
(`inventory_emit_manifest` even self-invokes `inventory_scan` only when
`CONJURE_INVENTORY_ITEMS` is empty), so if a caller populates
`CONJURE_INVENTORY_ITEMS` directly (or a symlink slips through), the emit path will
classify it. `inventory_classify` does return `SKIP:symlink`, and line 278 handles
that — so the net effect is defended *only* because `inventory_classify` is called
first. This is fragile defense-in-depth: the comment at line 277 says "double-check"
but the `-f` test at 267 is the wrong primitive and runs *before* the classify call.
**Fix:** Add an explicit symlink skip in the emit loop, mirroring the scan loop:
```bash
[ -L "${filepath}" ] && continue
[ ! -f "${filepath}" ] && continue
```

### WR-07: `inventory_emit_manifest` discards `inventory_scan` exit status and proceeds on partial data

**File:** `lib/inventory.sh:242-244`
**Issue:** The internal guard `if [ -z "${CONJURE_INVENTORY_ITEMS}" ]; then
inventory_scan "${target}"; fi` ignores `inventory_scan`'s return code. If the scan
partially fails (e.g. one of the five `mktemp` calls fails, or `find` errors), the
function continues and emits a manifest reflecting incomplete inventory, with
`total_files`/`total_found` that disagree silently. There is no error propagation to
the caller and no log entry marking the inventory as degraded. For a tool whose core
value is "auditable" and "trustworthy," a silently truncated manifest is a correctness
hazard.
**Fix:** Check the scan result and abort/log on failure:
```bash
if [ -z "${CONJURE_INVENTORY_ITEMS}" ]; then
  inventory_scan "${target}" || {
    [ -n "${RESTRUCTURE_LOG_PATH:-}" ] && log_step INVENTORY "scan failed for ${target}"
    return 1
  }
fi
```

### WR-08: `log_fail` calls `log_step` which depends on `mutate_write` succeeding — failure during failure is swallowed

**File:** `lib/log.sh:47-51`
**Issue:** `log_fail` writes a FAIL entry via `log_step` → `mutate_write --append`,
then `exit 2`. If `RESTRUCTURE_LOG_PATH` is unset/empty (the default at line 8) or
the log directory is not writable, `mutate_write` runs `printf '%s' "$content" >>
"$dest"` with an empty `$dest`, which under bash is a redirection error to an empty
filename. The fatal message is then lost and the only signal is the bare `exit 2`.
Because `log_step` is also reachable before `log_init` sets the path, the FAIL message
can vanish exactly when it matters most.
**Fix:** Guard the write target and fall back to stderr:
```bash
log_fail() {
  local message="$1"
  if [ -n "${RESTRUCTURE_LOG_PATH:-}" ]; then
    log_step "FAIL" "${message}"
  fi
  printf '%s\n' "[FAIL] ${message}" >&2
  exit 2
}
```

## Info

### IN-01: `mutate_summary` message says "DRY_RUN" semantics when counter alone triggered

**File:** `lib/mutate.sh:133-137`
**Issue:** When `DRY_RUN` is `0` but `CONJURE_DRY_MUTATION_COUNT > 0` (per the
documented per-command-prefix case), the summary still prints
`"[dry-run] N mutations skipped — run without --dry-run to apply"`. In live mode with
a leftover/initialized counter this message is misleading. Low impact but can confuse
operators reading logs.
**Fix:** Distinguish the two cases, or reset `CONJURE_DRY_MUTATION_COUNT=0` at the
start of a live run.

### IN-02: `snapshot_rollback` second-branch `cp -Rp "${snapshot_path}" "${target}/"` nests the snapshot dir

**File:** `lib/snapshot.sh:77-82`
**Issue:** The fallback `cp -Rp "${snapshot_path}" "${target}/"` (no trailing `/.`)
copies the snapshot *directory itself* into `${target}/`, producing
`${target}/conjure-adopt-<ts>/...` rather than restoring contents into `${target}`.
The primary `cp -a "${snapshot_path}/." "${target}/"` is correct; the fallback changes
semantics. Only reached when the first `cp` fails, but on that path the rollback is
silently wrong. (Same shape exists in `snapshot_create` lines 32-34, where the
fallback also nests.)
**Fix:** Use `cp -Rp "${snapshot_path}/." "${target}/"` in both fallbacks to match the
primary's contents-copy semantics.

### IN-03: `snapshot_list` literal-glob leak when no snapshots exist

**File:** `lib/snapshot.sh:97`
**Issue:** `ls -1t "${backup_root}"/conjure-adopt-* 2>/dev/null` relies on `ls`
erroring (suppressed) when the glob does not expand. Under bash this passes the
literal pattern to `ls`; the `2>/dev/null` hides the resulting error, so the function
correctly emits nothing — but it depends on default (non-`failglob`, non-`nullglob`)
shell options. If a caller sets `failglob`/`nullglob`, behavior changes.
**Fix:** Guard with a `nullglob`-style check or test for existence first; or document
the required glob options.

### IN-04: Schema allows empty `target` / `snapshot_path` strings (no `minLength`)

**File:** `adopt-manifest.schema.json:34-41`
**Issue:** `target` is required and typed `string` but lacks `minLength: 1`. Combined
with WR-05, an empty `target` validates cleanly. `snapshot_path` is intentionally
empty at inventory time (documented), so it should stay unconstrained, but `target`
should be a non-empty absolute path.
**Fix:** Add `"minLength": 1` to the `target` property.

### IN-05: `audit-setup.sh` exit-code contract conflicts with CLAUDE.md hook rule (informational)

**File:** `scripts/audit-setup.sh:297`
**Issue:** The script exits `1` on warnings (`[ "$WARN" -gt 0 ] && exit 1`). CLAUDE.md
states "hooks `exit 2` (never `exit 1`)." `audit-setup.sh` is a CLI audit tool, not a
Claude Code hook, so this is *not* a violation — but the proximity to the hook rule
and the fact that `tests/run.sh` treats rc=1 as "warnings" warrants a one-line comment
clarifying that this script is intentionally exempt from the hook exit-code rule, to
prevent a future "fix" that breaks the test harness's rc interpretation.
**Fix:** Add a comment near the exit block noting the tool/hook distinction.

### IN-06: `generate-large.sh` uses `exit 1` and ignores `mkdir` failure

**File:** `tests/fixtures/brownfield-simple/generate-large.sh:12, 16`
**Issue:** Usage-error path uses `exit 1`; harmless for a fixture generator but
inconsistent with the project's exit-code conventions elsewhere. Also `mkdir -p
"${DEST}"` return value is not checked, so on failure the loop writes nothing and the
script still reports "Generated 510 .md files," which could mask a fixture-setup
failure in CI.
**Fix:** Check `mkdir -p "${DEST}" || { echo "mkdir failed: ${DEST}" >&2; exit 1; }`.

---

_Reviewed: 2026-05-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
