# Phase 09: 3-Way Merge — Validation

This document provides executable verification commands a contributor can run
to confirm phase 09 behavior is correct after implementation. All commands
assume the working directory is the repo root and CONJURE_HOME is the repo root.

---

## Verify Commands

### MERGE-01: conjure update --apply uses git merge-file

Confirm the core merge primitive is present in the merge library.

```bash
grep -q 'git merge-file' lib/merge.sh && echo "PASS: merge-file present" || echo "FAIL: merge-file missing"
```

Expected output: `PASS: merge-file present`

---

### MERGE-02: conjure init writes snapshot directory

Confirm that running `conjure init` on a new target creates the
`.conjure-templates-<version>/` snapshot directory containing user-owned templates.

```bash
tmpdir=$(mktemp -d)
CONJURE_HOME="$(pwd)" DRY_RUN=0 cli/conjure init "$tmpdir" >/dev/null 2>&1
ver=$(cat "$tmpdir/.claude/.conjure-version" 2>/dev/null)
if [ -d "$tmpdir/.claude/.conjure-templates-${ver}" ] && \
   [ -f "$tmpdir/.claude/.conjure-templates-${ver}/CLAUDE.md.tmpl" ]; then
  echo "PASS: snapshot written at .conjure-templates-${ver}/"
else
  echo "FAIL: snapshot directory or CLAUDE.md.tmpl missing"
fi
rm -rf "$tmpdir"
```

Expected output: `PASS: snapshot written at .conjure-templates-<version>/`

---

### MERGE-03: Conflict creates sidecar, original untouched

Confirm that when user and upstream edit the same line, `merge_file_3way` writes
the conflict output to a sidecar file and leaves the original file unchanged.

```bash
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.claude/skills/testskill"

# base (ancestor) — shared starting point
printf 'conflict_line: base\n' > "$tmpdir/base.md"
# current — user's version
printf 'conflict_line: USER_VERSION\n' > "$tmpdir/.claude/skills/testskill/SKILL.md"
# new upstream
printf 'conflict_line: UPSTREAM_VERSION\n' > "$tmpdir/new.md"

# Source libs
# shellcheck disable=SC1091
source lib/mutate.sh
# shellcheck disable=SC1091
source lib/merge.sh

CONJURE_MERGE_CONFLICT_COUNT=0
CONJURE_MERGE_CONFLICT_FILES=""
DRY_RUN=0 merge_file_3way \
  "$tmpdir/.claude/skills/testskill/SKILL.md" \
  "$tmpdir/base.md" \
  "$tmpdir/new.md" \
  "skills/testskill/SKILL.md" "0.0.1" "0.3.0"
rc=$?

if [ "$rc" -eq 1 ]; then
  echo "PASS: merge_file_3way returns 1 on conflict"
else
  echo "FAIL: expected rc=1, got rc=$rc"
fi

# Original must still contain USER_VERSION and no conflict markers
if grep -q "USER_VERSION" "$tmpdir/.claude/skills/testskill/SKILL.md" && \
   ! grep -q '<<<<<<<' "$tmpdir/.claude/skills/testskill/SKILL.md"; then
  echo "PASS: original file untouched"
else
  echo "FAIL: original file was modified (D-05 violation)"
fi

sidecar="$tmpdir/.claude/skills/testskill/.conjure-conflict-skills_testskill_SKILL.md"
if [ -f "$sidecar" ] && grep -q '<<<<<<<' "$sidecar"; then
  echo "PASS: sidecar written with conflict markers"
else
  echo "FAIL: sidecar missing or has no markers (expected at $sidecar)"
fi

rm -rf "$tmpdir"
```

Expected output (3 lines):
```
PASS: merge_file_3way returns 1 on conflict
PASS: original file untouched
PASS: sidecar written with conflict markers
```

---

### MERGE-04: settings.json takes upstream unconditionally

Confirm that `conjure update --apply` replaces settings.json with the upstream
template without running a 3-way merge or creating a sidecar.

```bash
tmpdir=$(mktemp -d)
ver="$(grep '^CONJURE_VERSION=' cli/conjure | head -1 | cut -d= -f2 | tr -d "'\"")"
mkdir -p "$tmpdir/.claude/.conjure-templates-${ver}"
# Stale settings with a unique sentinel value
printf '{"conjure_test_stale_key": "should_be_replaced"}\n' \
  > "$tmpdir/.claude/settings.json"
printf '%s\n' "$ver" > "$tmpdir/.claude/.conjure-version"

CONJURE_HOME="$(pwd)" cli/conjure update --apply "$tmpdir" >/dev/null 2>&1

if ! grep -q '"conjure_test_stale_key"' "$tmpdir/.claude/settings.json" 2>/dev/null; then
  echo "PASS: settings.json stale key replaced by upstream"
else
  echo "FAIL: settings.json still contains stale key after --apply"
fi

if [ -z "$(find "$tmpdir/.claude" -name '.conjure-conflict-*settings*' 2>/dev/null)" ]; then
  echo "PASS: no conflict sidecar for settings.json"
else
  echo "FAIL: sidecar written for generated file (should take upstream unconditionally)"
fi

rm -rf "$tmpdir"
```

Expected output:
```
PASS: settings.json stale key replaced by upstream
PASS: no conflict sidecar for settings.json
```

---

### MERGE-05: conjure audit detects conflict markers

Confirm that `conjure audit` (scripts/audit-setup.sh) exits non-zero and prints
an error message when a real harness file contains `<<<<<<<` conflict markers.
Confirm sidecar files with markers are NOT flagged as false positives.

```bash
# Part A: conflict markers in a real harness file → audit fails
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.claude"
printf '<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> upstream\n' \
  > "$tmpdir/.claude/CLAUDE.md"
out="$(bash scripts/audit-setup.sh "$tmpdir" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'Unresolved merge conflicts'; then
  echo "PASS: audit detects conflict markers and exits non-zero (MERGE-05)"
else
  echo "FAIL: audit should exit non-zero and report 'Unresolved merge conflicts'"
fi
rm -rf "$tmpdir"

# Part B: sidecar file with markers → audit does NOT flag it
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.claude"
printf '<<<<<<< markers\nA\n=======\nB\n>>>>>>> end\n' \
  > "$tmpdir/.claude/.conjure-conflict-CLAUDE.md"
printf 'clean content\n' > "$tmpdir/.claude/CLAUDE.md"
out="$(bash scripts/audit-setup.sh "$tmpdir" 2>&1)"
if printf '%s\n' "$out" | grep -q 'Unresolved merge conflicts'; then
  echo "FAIL: sidecar file incorrectly flagged as conflict (false positive)"
else
  echo "PASS: sidecar file excluded from conflict detection (no false positive)"
fi
rm -rf "$tmpdir"
```

Expected output:
```
PASS: audit detects conflict markers and exits non-zero (MERGE-05)
PASS: sidecar file excluded from conflict detection (no false positive)
```

---

## Full Regression Suite

Run the complete test suite to verify all MERGE scenarios pass:

```bash
bash tests/run.sh 2>&1 | grep -E '(MERGE|PASS|FAIL)' | tail -20
bash tests/run.sh 2>&1 | tail -3
```

Expected: final line shows `FAIL: 0`.

---

## Shellcheck Gate

Confirm all modified files pass shellcheck with project CI flags:

```bash
shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 lib/merge.sh scripts/audit-setup.sh tests/run.sh cli/conjure
echo "shellcheck exit: $?"
```

Expected: exits 0.
