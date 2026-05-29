---
phase: 23-restructure-skill-safety-gates
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - templates/skills/restructure/SKILL.md
  - templates/skills/restructure/gates/verify-invariants.sh
  - templates/skills/restructure/gates/audit-staged.sh
  - templates/skills/restructure/gates/extract-invariants.sh
  - templates/skills/restructure/gates/decision-scan.sh
  - templates/skills/restructure/gates/approve.sh
  - scripts/init-project.sh
  - scripts/check.sh
findings:
  critical: 1
  warning: 3
  info: 4
  total: 8
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-05-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 23 ships the human-gated `restructure` skill plus five pre-write safety-gate
helpers, the `conjure adopt` seam wiring, and supporting `check.sh` /
`init-project.sh` edits. The bulk of the work is sound: the path-traversal chokepoint
in `extract-invariants.sh` resists every bypass I threw at it; the `audit-staged.sh`
cap boundary is exactly right (100 passes, 101 blocks) and `grep -c ''` counts
trailing-newline-less files correctly; the decision-scan vocabulary matches the
documented 5 terms with no under-flagging gap; the `check.sh` skill-resource
registration correctly preserves drift coverage and adds the gate files; all six
scoped scripts pass the CI shellcheck gate (`-S error -e SC2164,SC2044,SC2034,SC2155`)
clean; SKILL.md is 110 lines (under the 200 cap) and declares
`allowed-tools: [Read, Bash]` / `disallowed-tools: [Write, Edit]`.

The one BLOCKER is a sequencing defect in `approve.sh`: its bucket-approval jq selects
**any** step (including `op: archive`) whose `.src`/`.dest` matches a bucket file path,
with no `.op` filter. With the shipped fixture manifest this causes an `archive` op to
be applied during a non-archive bucket approval — directly violating D-15 ("archive
sequenced LAST") and bypassing the `decision-scan.sh` individual-vs-bulk escalation
(the exact mechanism that prevents an active-decision file from being silently bulk-
archived — CR-6 HIGH). Three warnings cover a false security claim in SKILL.md, the
`CONJURE_FORCE_INTERACTIVE` auto-approve bypass surface, and the substring-granularity
weakness in `verify-invariants.sh`.

## Critical Issues

### CR-01: approve.sh applies `op: archive` steps during non-archive bucket approval (violates D-15 / bypasses decision-scan)

**File:** `templates/skills/restructure/gates/approve.sh:136-138`
**Issue:**
The bucket-approval step collector selects steps by path match with **no filter on
`.op`**:
```
jq -r --arg p "$p" \
  '.restructure_steps[]?|select((.dest==$p) or (.src==$p) or ((.src // "")|endswith("/"+$p)))|.id' \
  "$MANIFEST" ...
```
An `op: archive` step records the project file being archived as `.src` (e.g.
`docs/OLD.md`), and that same file appears in `files[]` with a non-archive
classification (e.g. `reference-doc`). When the user approves the `reference-doc`
bucket, this jq matches the archive step via `select(.src==$p)` and applies it through
`conjure adopt --apply-step` at line 145.

Verified against the shipped fixture `tests/fixtures/_adopt-restructure-steps/adopt-manifest.json`:
`step-2` is `{op: archive, src: "docs/OLD.md"}` and `docs/OLD.md` is classified
`reference-doc`. Approving the `reference-doc` bucket therefore fires the archive
**during** the per-class approval loop.

This directly contradicts the skill's own contract and multiple decisions:
- SKILL.md step 6 / line 100-101 + 70-71: archive is sequenced **LAST** (D-15) and
  every archive candidate MUST first pass `gates/decision-scan.sh` for the
  individual-vs-bulk escalation (D-11).
- approve.sh's own header (lines 12-14, 101-103) asserts it "groups only the
  non-archive classification buckets" and that "archive ops are sequenced LAST by the
  SKILL.md."

The consequence is the CR-6 HIGH failure mode the decision-scan gate exists to
prevent: a file carrying an active decision (e.g. `decided`/`rationale`) gets
bulk-archived without the individual `/dev/tty` confirm, because the archive never
routes through `decision-scan.sh` at all — it is applied as a side effect of a
reference-doc approval.

**Fix:** Exclude archive ops from the bucket collector so archive sequencing stays the
SKILL/decision-scan responsibility:
```sh
jq -r --arg p "$p" \
  '.restructure_steps[]?
   | select(.op != "archive")
   | select((.dest==$p) or (.src==$p) or ((.src // "")|endswith("/"+$p)))
   | .id' \
  "$MANIFEST" 2>/dev/null >> "$steps_tmp"
```
(Also consider restricting to `select(.status=="proposed")` so an already-applied or
skipped step is never re-applied on a second pass.)

## Warnings

### WR-01: SKILL.md security claim "env var is NOT forwarded through the CLI" is false — `CONJURE_ADOPT_STEP_JSON` wins over stdin

**File:** `templates/skills/restructure/SKILL.md:24-26, 95-96`
**Issue:**
SKILL.md asserts the op is registered "over **stdin only**" and that "The env var is
NOT forwarded through the CLI (`cli/conjure` does not plumb `CONJURE_ADOPT_STEP_JSON`)."
This is incorrect. `cli/conjure`'s `cmd_adopt` does not `unset`/scrub the environment,
so `CONJURE_ADOPT_STEP_JSON` is transparently **inherited** by the child
`bash scripts/adopt.sh` process, and `adopt.sh:423` reads it with **higher priority
than stdin** (`local step_json="${CONJURE_ADOPT_STEP_JSON:-}"` then falls back to
`cat` only when empty).

Verified empirically: running `CONJURE_ADOPT_STEP_JSON="$op" conjure adopt
--update-manifest <target> </dev/null` (empty stdin) appended the op to
`restructure_steps[]` and returned rc 0 — the env var, not stdin, drove the write.

This is not directly exploitable by the well-behaved skill (it won't set the var), but
the threat-model statement is the opposite of the actual behavior. A future maintainer
trusting "stdin only" could remove the stdin path or weaken stdin validation believing
the env channel is closed, when in fact the env channel is the dominant one.

**Fix:** Either (a) correct SKILL.md to state the truth — "the op may be supplied via
stdin OR `CONJURE_ADOPT_STEP_JSON`; the skill uses stdin" — or (b) make the claim true
by scrubbing the var in `cli/conjure cmd_adopt` before exec
(`unset CONJURE_ADOPT_STEP_JSON`) so stdin genuinely is the only inbound channel. Option
(b) is the safer hardening since it matches the documented chokepoint intent.

### WR-02: `CONJURE_FORCE_INTERACTIVE=1` bypasses the non-TTY no-auto-approve guard (D-12)

**File:** `templates/skills/restructure/gates/approve.sh:32`
**Issue:**
The D-12 guard ("never auto-approve on non-TTY") is short-circuited by
`CONJURE_FORCE_INTERACTIVE=1`:
```sh
if ! { [ -t 0 ] || [ "${CONJURE_FORCE_INTERACTIVE:-0}" = "1" ]; }; then
  ... exit 2
fi
```
When that env var is set, the guard passes even with a non-TTY stdin, and
`PROMPT_SRC` becomes `/dev/stdin` (lines 81-85) — i.e. the approval verb is read from
a redirected/piped stdin rather than an interactive terminal. The skill executes in a
non-interactive automation context (Claude Code Bash tool) where stdin is not a TTY; if
this env var is present in that environment, an automated `a` on stdin would
auto-approve and apply mutations with no human at a terminal, defeating the central
RESTR-02/D-12 safety property. The mitigation today is purely that the var is
"test-only" by convention and is mirrored from `resolve.sh:34` / `adopt.sh:808`, but
there is no enforcement that it is unset in production.

**Fix:** At minimum, document the live-context risk prominently in SKILL.md ("the skill
MUST NOT set or inherit `CONJURE_FORCE_INTERACTIVE`"). Better: gate the escape hatch on
an additional test-only marker (e.g. require `CONJURE_TEST=1` as well) so an
accidentally-inherited `CONJURE_FORCE_INTERACTIVE` cannot by itself open the
auto-approve path.

### WR-03: verify-invariants substring matching can false-pass a dropped invariant on a short/common token

**File:** `templates/skills/restructure/gates/verify-invariants.sh:41-44`
**Issue:**
The verifier confirms an invariant is "present" via a normalized **substring** test
(`case "$HAYSTACK" in *"$needle"*)`). A short or common canonical token (e.g.
`exit 2`, `never`) can match incidentally anywhere in the condensed file — a code
fence, an unrelated sentence, a verb in prose — even when the actual invariant rule was
dropped. Because a coincidental match counts as present, a genuinely dropped security
invariant can falsely pass GATE A (the CR-1 HIGH false-pass risk). The match is also
polarity-blind: `exit 2` matches inside "do NOT exit 2", so an inverted rule passes.
This is partly inherent to the substring design (and the LLM is expected to choose
canonical tokens), but the helper offers no guard against degenerate-short tokens.

**Fix:** Add a minimum-specificity guard — reject/ warn on canonical tokens shorter than
N normalized chars (e.g. < 4), and prefer multi-word distinctive tokens. Document in
SKILL.md step 2 that confirmed invariants must be distinctive multi-word phrases
(e.g. `hooks exit 2` not `exit 2`, `do not delete user files` not `delete`) so the
substring test cannot be satisfied incidentally. Consider requiring the token appear as
a whole-line or sentence-anchored match for single-word terms.

## Info

### IN-01: init-project.sh uses `exit 1` (project convention is `exit 2`)

**File:** `scripts/init-project.sh:17`
**Issue:** The usage-error path exits 1, which violates the project-wide "never
`exit 1`, use `exit 2`" convention (CLAUDE.md, and enforced elsewhere in adopt.sh,
log.sh, all gate helpers). This line is pre-existing (this phase's diff only added the
word `restructure` to line 59), so it is not a regression introduced here, but it is in
the reviewed file and contradicts the convention the new helpers follow.
**Fix:** Change `exit 1` → `exit 2` on the usage-error branch for consistency.

### IN-02: approve.sh `[a]pprove` swallows per-step apply failures silently

**File:** `templates/skills/restructure/gates/approve.sh:145-147`
**Issue:** Each `conjure adopt --apply-step` is run with `>/dev/null 2>&1` and only
increments `applied` on success; failures are silently dropped. The bucket summary then
reports "applied N step(s)" where N may be less than the number of steps attempted,
with no indication that some failed. A failed apply (e.g. a path-rejected write) leaves
the user believing the bucket was processed.
**Fix:** Track a `failed` counter and surface it in the summary line / log
(`approved $bucket bucket — applied $applied, $failed failed`), and consider not
suppressing stderr on failure so the human sees why a step did not apply.

### IN-03: approve.sh leaks temp files if `--apply-step` aborts the process

**File:** `templates/skills/restructure/gates/approve.sh:128-150`
**Issue:** `paths_tmp` and `steps_tmp` are created with `mktemp` and removed at
line 150, but there is no `trap` cleanup. If any `apply-step` invocation or the script
is interrupted between creation and the `rm -f`, the temp files leak. Unlike
audit-staged.sh (which uses `trap 'rm -rf "$tmp"' EXIT`), approve.sh has no EXIT trap
for these.
**Fix:** Register an EXIT trap that removes both temp files, or scope them under a
single `mktemp -d` with one trap.

### IN-04: check.sh `grep -qF "$rel"` added-file detection is a substring match (latent false-negative)

**File:** `scripts/check.sh:106`
**Issue:** Added-file detection uses `grep -qF "$rel" "$MANIFEST"` — an unanchored
fixed-string **substring** match. If a harness file's relative path is a substring of a
different registered manifest path, the added file is falsely treated as "registered"
(not flagged as added drift). With the new skill-resource registration adding nested
paths like `.claude/skills/restructure/gates/approve.sh`, the manifest now contains
longer paths that increase the chance of a short added path being a coincidental
substring. This line is in the unchanged portion of check.sh (not introduced by this
phase) but the phase's new nested registrations raise its exposure.
**Fix:** Anchor the match to whole lines: `grep -qxF "$rel" "$MANIFEST"` (the `-x`
flag requires a full-line match), eliminating substring false-negatives.

---

_Reviewed: 2026-05-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
