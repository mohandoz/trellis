---
phase: 24-integration-tests-argus-fixture
fixed_at: 2026-05-29T00:00:00Z
review_path: .planning/phases/24-integration-tests-argus-fixture/24-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 3
skipped: 1
status: partial
---

# Phase 24: Code Review Fix Report

**Fixed at:** 2026-05-29
**Source review:** .planning/phases/24-integration-tests-argus-fixture/24-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (CR-01, WR-01, IN-01, IN-02)
- Fixed: 3 (CR-01, WR-01, IN-01)
- Accepted / no code change: 1 (IN-02)

All three code fixes landed in a single file
(`tests/fixtures/_brownfield-argus/generate-argus.sh`) and committed atomically.
Full test suite stayed green: **PASS 447 / FAIL 0** (no regression).

## Fixed Issues

### CR-01: Non-directory / unwritable target exits 0 instead of exit 2 — silent fixture-generation failure

**Files modified:** `tests/fixtures/_brownfield-argus/generate-argus.sh`
**Commit:** 7fd0fc8
**Applied fix:** Replaced the bare unchecked `mkdir -p "${TARGET}/docs"
"${TARGET}/generated-docs"` with a fail-closed guard: if the `mkdir -p` fails
(stderr suppressed) the script prints a clear error to stderr and `exit 2`. A
second defensive assertion follows — if the resulting `${TARGET}/docs` is not a
directory or not writable, it also prints to stderr and `exit 2`. The pre-existing
empty-arg `exit 2` guard (lines 27–31) is preserved untouched. Per the project
lock, the failure now exits 2 (never exit 1, never silent exit 0).

**Verification:** Ran the generator against a regular-FILE target
(`TF="$(mktemp)"; bash generate-argus.sh "$TF"`) → now `exit 2` with a single
loud stderr line (`generate-argus.sh: cannot create target dir '...' (not a
writable directory)`) instead of the prior ~509-error flood + `exit 0`.

### WR-01: Re-run into a non-empty target emits a spurious `ln: File exists` but still exits 0

**Files modified:** `tests/fixtures/_brownfield-argus/generate-argus.sh`
**Commit:** 7fd0fc8
**Applied fix:** Changed `ln -s real.md "${TARGET}/docs/linked.md"` to
`ln -sf ...`. The `-f` is safe here because the symlink target is always inside
the just-created sandbox. A re-run into a non-fresh dir is now clean.

**Verification:** Ran the generator twice into the same (non-fresh) dir → second
run `exit 0` with **zero** stderr bytes (was `ln: ... linked.md: File exists`
before), and the symlink remains a genuine relative symlink (`linked.md → real.md`).

### IN-01: Inline comment file-count math (505/255) contradicted the actual output (509/256)

**Files modified:** `tests/fixtures/_brownfield-argus/generate-argus.sh`
**Commit:** 7fd0fc8
**Applied fix:** Replaced the stale line-48 comment
(`~500 bulk .md files (505 total: 255 under docs/, 250 under generated-docs/)`)
with an accurate one: `255 doc-NNN.md + real.md (256) under docs/, 250
gen-NNN.md under generated-docs/; with root CLAUDE.md + with-import.md = 509 .md
total`, plus a note that the `docs/linked.md` symlink adds the 510th `.md` entry.
This now agrees with the header (lines 12/74) and the runtime echo (509 .md).

**Verification:** Confirmed actual output is 509 `.md` files via `find`.

## Accepted Issues (no code change)

### IN-02: Header cross-reference / provenance note about `brownfield-simple/generate-large.sh`

**File:** `tests/fixtures/_brownfield-argus/generate-argus.sh:3`
**Disposition:** Accepted — no code change required.
**Reason:** The reviewer's own Fix note states "No code change required;
addressing CR-01 makes the 'honors the project lock' claim fully true." The
CR-01 fix above closes the unwritable-target gap, so the header's "honors the
project lock 'exit 2 never exit 1'" framing is now accurate for both the
empty-arg path AND the unusable-target path. The comparator
(`brownfield-simple/generate-large.sh`) still has its own gap, but that is out
of scope for this phase's fix.

---

_Fixed: 2026-05-29_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
