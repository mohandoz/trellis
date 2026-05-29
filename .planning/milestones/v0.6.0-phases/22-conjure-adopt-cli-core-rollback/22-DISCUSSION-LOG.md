# Phase 22: `conjure adopt` CLI Core + Rollback - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 22-conjure-adopt-cli-core-rollback
**Areas discussed:** Rollback scope/cleanliness, --apply-step contract, Adoption report + dry-run plan, Partial-run recovery UX

---

## Rollback scope/cleanliness

### Restore strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Full restore + delete-created | `cp -a` whole snapshot over target, then delete every `created[]` path, then verify sha256(mutated[])==before | ✓ |
| Surgical (manifest-only) | Restore only recorded `mutated[]` paths, delete only `created[]`; never touch unrelated files | |
| Full restore only | Current `snapshot_rollback` unchanged; no delete-created → scaffolded files survive | |

**User's choice:** Full restore + delete-created (D-01)
**Notes:** Only path that yields Phase 24's sha256-identical before/after. `created[]` scoped to scaffolded harness paths only, not conjure's own backup dirs (D-02); Phase 24 zero-diff must exclude `.conjure-*` dirs (D-03).

### Post-rollback artifact handling

| Option | Description | Selected |
|--------|-------------|----------|
| Keep snapshot + log, remove state | Delete `.conjure-adopt-state`; keep snapshot dir, archive, `RESTRUCTURE-LOG.md` (with `[ROLLBACK]` entry) | ✓ |
| Remove everything | Delete all conjure artifacts for byte-identical tree | |
| Keep all, remove nothing | Leave everything incl. state file | |

**User's choice:** Keep snapshot + log, remove state (D-04)
**Notes:** Preserves "lose nothing" + audit trail; removing state prevents false recovery prompt on next run.

---

## --apply-step contract (Phase 23 seam)

### What --apply-step operates on

| Option | Description | Selected |
|--------|-------------|----------|
| Restructure-op from manifest | `--apply-step <id>` executes `restructure_steps[id]` via `mutate_*`; `--update-manifest` writes proposals; skill proposes, CLI applies | ✓ |
| Pipeline-step rerun | `--apply-step <step-name>` reruns one of the 5 pipeline steps idempotently | |
| Both (op + step-rerun) | Public op application + named step rerun | |

**User's choice:** Restructure-op from manifest (D-05, D-06)
**Notes:** Honors RESTR-02 chokepoint. Phase 22 ships executor + op types tested vs synthetic manifest; Phase 23 wires the skill (D-08).

### Op content delivery

| Option | Description | Selected |
|--------|-------------|----------|
| Staging-path reference | Skill writes content to `.conjure-adopt-state/staging/<file>`; op references `src` | ✓ |
| Inline content in manifest | Op carries full content string in `restructure_steps[]` | |

**User's choice:** Staging-path reference (D-07)
**Notes:** Keeps manifest lean; lets `--apply-step` + `conjure audit` inspect proposed content pre-write (sets up RESTR-05).

---

## Adoption report + dry-run plan

### Report format

| Option | Description | Selected |
|--------|-------------|----------|
| Labeled sections + delta block | Plain-text sections + compact before/after block, echo style consistent with cmd_audit/check | ✓ |
| Aligned metrics table | Single bordered/aligned printf table | |
| You decide | Leave format to planning | |

**User's choice:** Labeled sections + delta block (D-09)
**Notes:** No new deps; required metrics fixed by ADOPT-06.

### Dry-run concreteness

| Option | Description | Selected |
|--------|-------------|----------|
| Real read-only inventory | Run preconditions + inventory_scan for real, write manifest to temp path, print concrete plan with real numbers | ✓ |
| Static 5-step plan | Print generic sequence, no inventory | |

**User's choice:** Real read-only inventory (D-10)
**Notes:** Preview showed in-repo `.conjure-adopt-state/dry-run/` path; corrected to external `mktemp -d` (D-11) — ADOPT-02 + Phase 24 criterion 1 forbid any write under the target.

---

## Partial-run recovery UX

### What [c]ontinue does

| Option | Description | Selected |
|--------|-------------|----------|
| Resume at next incomplete step | Read `.conjure-adopt-state`, skip done steps (sha256-matched), resume at first incomplete, reuse snapshot | ✓ |
| Restart from step 1 (idempotent) | Re-run whole pipeline, rely on idempotency to no-op | |

**User's choice:** Resume at next incomplete step (D-12)
**Notes:** Reuses existing snapshot — no second backup.

### No-TTY behavior

| Option | Description | Selected |
|--------|-------------|----------|
| exit 2 + explicit recovery flags | Read prompt from /dev/tty; no TTY → print state + exit 2; CI uses --rollback/--resume/--start-fresh | ✓ |
| Auto-rollback in non-TTY | Non-TTY auto-undoes partial run | |
| Auto-continue in non-TTY | Non-TTY auto-resumes | |

**User's choice:** exit 2 + explicit recovery flags (D-13)
**Notes:** Mirrors resolve.sh + ADOPT-03 exit-2 precedent; never auto-mutate. Interactive prompt has no default — empty re-prompts (D-14).

---

## Claude's Discretion

- `.conjure-adopt-state` exact JSON schema (step records, sha256 before/after, `created[]`/`mutated[]`, staging layout)
- Scaffold reuse mechanism (subprocess `init-project.sh` vs inline) — default subprocess
- Signal-trap mechanics + per-step log wording + completion-record ordering
- `--force` vs recovery prompt independence (confirm during planning)

## Deferred Ideas

- `--json` report/inventory output — ADOPT-07 (v2)
- `--quick` inventory mode — ADOPT-08 (v2)
- The `restructure` skill that generates ops + constraint pre-pass + pre-write audit gate — Phase 23
