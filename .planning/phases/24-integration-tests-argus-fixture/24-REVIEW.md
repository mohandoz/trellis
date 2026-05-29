---
phase: 24-integration-tests-argus-fixture
reviewed: 2026-05-29T03:44:31Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - tests/fixtures/_brownfield-argus/generate-argus.sh
  - scripts/adopt.sh
findings:
  critical: 1
  warning: 1
  info: 2
  total: 4
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-05-29T03:44:31Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

This is a test-harness + 1-line phase, reviewed proportionately and adversarially.

The `scripts/adopt.sh` `report()` O-1 deviation is **clean**: a single additive `[ "${created_count:-0}" -eq 0 ] && echo "  Scaffolded:  nothing to scaffold"` (verified `git show 66d19ff` = exactly 1 insertion). It preserves the `Scaffolded:  N layer files` count line, fires ONLY on a zero-scaffold run (verified: fresh run scaffolds 47 layers and does NOT emit the phrase; idempotent re-run scaffolds 0 and emits BOTH lines), and cannot alter exit codes or any other report content (`report()`'s return value is discarded — `run_pipeline` calls `mutate_summary` right after). The guard `created_count` is sourced from `jq -r '.created | length' ... || echo 0`, and `jq length` returns a numeric `0` for missing-key / explicit-null / empty-array, with the `|| echo 0` covering any jq failure — so the `-eq` comparison is always integer-safe in every reachable state. No defect found in the adopt.sh change.

The generator `generate-argus.sh` works correctly on the happy path that the test harness exercises (fresh `mktemp` dir): it materializes 509 `.md` files, a genuine relative `ln -s` symlink (`docs/linked.md → real.md`, verified `[ -L ]` true and `readlink` = `real.md`), a 127-line oversized CLAUDE.md, and an `@import` seed — all quoted (paths with spaces verified), all written strictly inside the passed target (no escape). It is shellcheck-clean under the project flags (`-S error -e SC2164,SC2044,SC2034,SC2155`), and a missing target arg correctly exits 2.

However, the generator has **one real safety defect the phase context explicitly asked to verify**: a non-directory (or otherwise unwritable) target is NOT handled with `exit 2` — the script floods stderr with ~509 errors and then exits **0 (success)**. This is a direct violation of the "exit 2 never exit 1 / fail-loud" project lock, and it produces a silently-unusable fixture. A related (lower-severity) consequence of the same missing error-propagation is that a non-fresh re-run emits a spurious `ln: File exists` to stderr while still exiting 0.

## Critical Issues

### CR-01: Non-directory / unwritable target exits 0 (success) instead of exit 2 — silent fixture-generation failure

**File:** `tests/fixtures/_brownfield-argus/generate-argus.sh:25,33,46`

**Issue:** The script runs under `set -uo pipefail` (line 25) but does **not** check the result of the only structural command, `mkdir -p "${TARGET}/docs" "${TARGET}/generated-docs"` (line 33). When the target is a path that cannot be a directory (e.g. an existing regular file, or a path nested under a regular file), `mkdir -p` fails, every subsequent redirect (`> "${TARGET}/CLAUDE.md"`, the 505 `doc-*.md` / `gen-*.md` writes, `ln -s`) fails too, the script prints ~509 errors to stderr — and then **exits 0** because the final `echo` on line 74 succeeds and there is no `set -e`. Reproduced:

```
$ TF="$(mktemp)"; bash generate-argus.sh "$TF"; echo "rc=$?"
mkdir: .../tmp.XXXX: Not a directory
... (≈509 redirect errors) ...
rc=0          # ← should be 2
```

This breaks the exact contract the phase context asked to confirm ("a missing/!-dir target arg is handled (exit 2)"). Only the empty-arg case (lines 28–31) is guarded; the unusable-target case reports success while producing no usable fixture. Per the project lock, a hard failure must `exit 2`, never silently succeed.

**Fix:** Fail closed on the `mkdir` (and, defensively, assert the target resolves to a writable directory before generating). Add right after line 27 / replace line 33:

```bash
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: bash generate-argus.sh <target-dir>" >&2
  exit 2
fi

if ! mkdir -p "${TARGET}/docs" "${TARGET}/generated-docs" 2>/dev/null; then
  echo "generate-argus.sh: cannot create target dir '${TARGET}' (not a writable directory)" >&2
  exit 2
fi
if [ ! -d "${TARGET}/docs" ] || [ ! -w "${TARGET}/docs" ]; then
  echo "generate-argus.sh: target '${TARGET}' is not a writable directory" >&2
  exit 2
fi
```

## Warnings

### WR-01: Re-run into a non-empty target emits a spurious `ln: File exists` to stderr but still exits 0

**File:** `tests/fixtures/_brownfield-argus/generate-argus.sh:68`

**Issue:** The header advertises the script as "idempotent-ish (safe to run into a fresh mktemp)", but `ln -s real.md "${TARGET}/docs/linked.md"` (line 68) is not idempotent: a second run into the same directory fails because `linked.md` already exists. Reproduced:

```
run1 rc=0
run2 stderr: ln: .../docs/linked.md: File exists
run2 rc=0     # error swallowed (no set -e; final echo succeeds)
```

The original symlink survives from run 1, so the fixture is not corrupted, and the test harness always uses a fresh `mktemp` dir — so the impact is contained. But the script swallows a real error (same missing-error-propagation root cause as CR-01) and prints a misleading error during an operation it claims to support. This degrades robustness/debuggability if the generator is ever re-pointed at a dirty dir.

**Fix:** Make the symlink creation idempotent (and force-overwrite is safe here since the target is always inside the just-created sandbox):

```bash
ln -sf real.md "${TARGET}/docs/linked.md"
```

If `-f` is undesirable (to keep the "genuine symlink, never overwritten" intent explicit), guard it instead:

```bash
[ -e "${TARGET}/docs/linked.md" ] || ln -s real.md "${TARGET}/docs/linked.md"
```

## Info

### IN-01: Inline comment file-count math (505/255) contradicts the header and the actual output (509/256)

**File:** `tests/fixtures/_brownfield-argus/generate-argus.sh:48`

**Issue:** Line 48's comment reads `~500 bulk .md files (505 total: 255 under docs/, 250 under generated-docs/)`. The actual totals are: `docs/` contains 256 real `.md` files (255 `doc-NNN.md` + `real.md`) plus the `linked.md` symlink = 257 `.md` entries; `generated-docs/` contains 250; plus 2 at root (`CLAUDE.md` + `with-import.md`) = **509 `.md` files total** (verified with `find`, and matching the header on lines 12/74 and the runtime echo). The "505 total / 255 under docs/" figures in the line-48 comment are stale/wrong and disagree with the script's own header and emitted count.

**Fix:** Correct the comment to match reality, e.g. `# (2) bulk .md files: 255 doc-NNN.md + real.md (256) under docs/, 250 gen-NNN.md under generated-docs/.`

### IN-02: Header cross-reference points at a non-existent sibling path (`brownfield-simple/generate-large.sh` shape claim)

**File:** `tests/fixtures/_brownfield-argus/generate-argus.sh:3`

**Issue:** The header says it "Mirrors brownfield-simple/generate-large.sh's shape, but honors the project lock 'exit 2 never exit 1' on the usage error." The referenced comparator does exist at `tests/fixtures/brownfield-simple/generate-large.sh`, and indeed it uses `exit 1` on its usage error (line 13) — so the "honors exit 2" framing is accurate and a genuine improvement over the comparator. The caveat: the comparator it claims to mirror itself does NOT enforce exit-2 on a bad target either (same CR-01 gap), so "mirrors its shape" inadvertently inherited the unsafe no-`mkdir`-check pattern. This is documentation/provenance only — no behavior impact beyond CR-01 — but worth noting so the comparator is not treated as the safety baseline.

**Fix:** No code change required; addressing CR-01 makes the "honors the project lock" claim fully true (it currently holds only for the empty-arg path, not the unwritable-target path).

---

_Reviewed: 2026-05-29T03:44:31Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
