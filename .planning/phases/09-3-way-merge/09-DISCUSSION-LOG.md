# Phase 09: 3-Way Merge - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 09-3-way-merge
**Areas discussed:** Missing snapshot fallback, Snapshot scope, Sidecar naming/placement, Test coverage approach

---

## Missing Snapshot Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Abort + instruct re-init | Print error, tell user to re-run `conjure init`, exit non-zero | ✓ |
| Fall back to git tag lookup | Try extracting base from git tag for the pinned version | |
| Skip conflicted files + warn | Leave unchanged, warn, continue | |

**User's choice:** Abort + instruct re-init

| Sub-option | Description | Selected |
|------------|-------------|----------|
| Just `conjure init` again | No new flag; backup-before-mutate makes re-init safe | ✓ |
| New `--refresh-snapshot` flag | Targeted operation, but adds scope to this phase | |

**User's choice:** Just `conjure init` again — no new flag surface area
**Notes:** Keeps phase scope bounded; `conjure init` already has backup-before-mutate so re-running is safe.

---

## Snapshot Scope

| Option | Description | Selected |
|--------|-------------|----------|
| User-owned files only | CLAUDE.md + skills/ + agents/ — matches MERGE-04 exactly | |
| All templates | Full copy of `$CONJURE_HOME/templates/` | |

**User's choice:** User-owned files only (recommended)

| Sub-option | Description | Selected |
|------------|-------------|----------|
| CLAUDE.md + skills/ + agents/ | Strict MERGE-04 match | |
| CLAUDE.md + skills/ + agents/ + hooks/ templates | Include hooks since users can customize .mjs hooks post-init | ✓ |

**User's choice:** CLAUDE.md + skills/ + agents/ + hooks/ templates
**Notes:** Users do customize hooks after init, so hooks belong in the snapshot scope even though they weren't listed in MERGE-04's generated/user-owned examples.

---

## Sidecar Naming/Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Path-encoded basename | `.conjure-conflict-skills_architecture_SKILL.md`, placed next to original | ✓ |
| Basename only | `.conjure-conflict-SKILL.md` — collision risk | |
| Central staging dir | `.claude/.conjure-conflicts/` — all conflicts in one place | |

**User's choice:** Path-encoded basename next to original

| Sub-option | Description | Selected |
|------------|-------------|----------|
| Exit non-zero with list | Print sidecar paths, instruct resolve, exit 1 | ✓ |
| Exit 0 with warning | Non-blocking, but misses CI use case | |

**User's choice:** Exit non-zero with list (exit 1)
**Notes:** Exit 1 (not exit 2) because conflicts are user-resolvable; exit 2 reserved for unrecoverable errors.

---

## Test Coverage Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in tests/run.sh | Existing pattern; all 200 assertions live here | ✓ |
| Fixture sets in tests/fixtures/merge-*/ | New infrastructure layer | |

**User's choice:** Inline in tests/run.sh

**Required scenarios (all selected):**
- Clean 3-way merge (no conflict) — auto-merge, no sidecar
- Conflict scenario — sidecar written, original untouched, exit 1
- Missing snapshot abort — exit non-zero with error message
- Generated-file passthrough — `.conjure-version` + `settings.json` take upstream unconditionally

---

## Claude's Discretion

- Function naming inside `lib/merge.sh` (ARCHITECTURE.md suggests `merge_skill`/`merge_with_backup`)
- Exact error message wording
- Whether to update `.conjure-version` after clean merge only or after zero conflicts

## Deferred Ideas

None — discussion stayed within phase scope.
