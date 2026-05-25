# Phase 09: 3-Way Merge - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the stub at `cli/conjure:174-178` with a real `git merge-file --diff3`
implementation via a new `lib/merge.sh`. Write a base snapshot during
`conjure init` so future `conjure update --apply` runs always have a valid
ancestor. Handle conflicts as sidecar files (original untouched). Add conflict
marker detection to `conjure audit`.

Does NOT introduce an interactive conflict editor, new CLI commands beyond
`--apply` behavior changes, or UI surface area.

</domain>

<decisions>
## Implementation Decisions

### Missing Snapshot Fallback
- **D-01:** When `conjure update --apply` runs and `.claude/.conjure-templates-<version>/`
  does not exist for the pinned version, abort with a clear error message:
  `"No base snapshot for v<X>. Re-run 'conjure init' to write one, then update."`
  Exit non-zero. No git tag fallback, no silent skip — safe abort.
- **D-02:** No new `--refresh-snapshot` flag. The re-init instruction directs users to
  run `conjure init` again; backup-before-mutate ensures existing `.claude/` is preserved.

### Snapshot Scope
- **D-03:** `conjure init` writes only user-owned files into the snapshot directory
  `.claude/.conjure-templates-<version>/`:
  - `CLAUDE.md` template
  - `skills/` templates
  - `agents/` templates
  - `hooks/` templates (users can customize `.mjs` hooks post-init)
  Generated files (`.conjure-version`, `settings.json`) are NOT snapshotted —
  they take upstream unconditionally (MERGE-04) so no ancestor needed.

### Conflict Sidecar Naming and Placement
- **D-04:** Sidecar filename is path-encoded to avoid collision: replace `/` with `_`
  in the relative path (from `.claude/`), prefix with `.conjure-conflict-`.
  Example: `.claude/skills/architecture/SKILL.md` → sidecar named
  `.conjure-conflict-skills_architecture_SKILL.md`, placed next to the original file
  in `.claude/skills/architecture/`.
- **D-05:** Original live file is left untouched on conflict. Only the sidecar is written.
- **D-06:** After processing all files, if any conflicts occurred: print the list of
  sidecar paths, instruct user to resolve and delete sidecars, exit non-zero (exit 1).
  Clean runs exit 0.

### Test Coverage
- **D-07:** Merge regression tests live inline in `tests/run.sh` (existing pattern —
  all 200 assertions already there). No new fixture directories.
- **D-08:** Minimum required test scenarios:
  1. Clean 3-way merge (user + upstream changed different lines → auto-merge, no sidecar)
  2. Conflict scenario (same lines changed → sidecar written, original untouched, exit 1)
  3. Missing snapshot abort (no `.conjure-templates-<version>/` → exit non-zero, error message)
  4. Generated-file passthrough (`.conjure-version` + `settings.json` → take upstream unconditionally)

### Claude's Discretion
- Function naming inside `lib/merge.sh` (workflow uses `merge_skill` / `merge_with_backup`
  per ARCHITECTURE.md — planner can adjust to match bash naming conventions)
- Exact error message wording beyond the format specified in D-01 and D-06
- Whether to update `.conjure-version` after a clean merge or only after zero conflicts

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and success criteria
- `.planning/REQUIREMENTS.md` §"3-Way Merge — `cmd_update --apply` (TECH-01)"
  — MERGE-01 through MERGE-05, the five locked requirements
- `.planning/ROADMAP.md` §"Phase 09: 3-Way Merge"
  — success criteria (5 items) and phase goal

### Architecture decisions (merge design)
- `.planning/research/ARCHITECTURE.md` §"5. `lib/merge.sh` (TECH-01)"
  — function signatures, `cmd_update --apply` completion steps, anti-patterns
- `.planning/research/ARCHITECTURE.md` §"Anti-Pattern 3: Interactive merge editor"
  — cross-platform constraint; no `$VISUAL`/`vimdiff` spawning
- `.planning/research/ARCHITECTURE.md` §"Modified Components" §`cli/conjure`
  — exactly which lines to replace (stub at 174-178)
- `.planning/research/ARCHITECTURE.md` §"Modified Components" §`scripts/audit-setup.sh`
  — conflict marker check addition

### Existing code to read before implementing
- `cli/conjure` lines 132-178 — full `cmd_update` function (stub to replace)
- `cli/conjure` lines 52-90 — `cmd_init` function (add snapshot write here)
- `lib/mutate.sh` — write chokepoint; all new writes MUST route through here
- `scripts/audit-setup.sh` — understand exit code pattern (0=pass, 1=warn, 2=error)
  and where to inject conflict-marker check
- `tests/run.sh` — understand existing test ID conventions (MERGE-NN) before
  writing new test blocks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/mutate.sh` functions `mutate_cp`, `mutate_write`, `mutate_summary` — all new
  file writes in `lib/merge.sh` and `cmd_init` snapshot step must route through these
- `cmd_update` lines 157-165 — existing `find templates/skills -name SKILL.md` loop
  identifies which files differ; `--apply` can extend this loop with merge logic
- `scripts/audit-setup.sh` exit code pattern — exit 2 for hard errors, exit 1 for
  warnings; conflict markers are a hard error (exit 2, not exit 1)

### Established Patterns
- All workers source `lib/mutate.sh`; new `lib/merge.sh` sourced by `cmd_update --apply`
  in `cli/conjure` (same pattern as `cmd_init` sourcing `lib/mutate.sh`)
- Test IDs follow `MERGE-NN` convention (parallel to `SAFE-NN`, `COST-NN` etc.)
- Backup-before-mutate: `cp -R "$target/.claude" "$backup"` pattern from `cmd_migrate`
  is already available; reuse same idiom in `cmd_update --apply`

### Integration Points
- `cmd_init` in `cli/conjure:52-90` — add snapshot write after `mutate_write .conjure-version`
  at line 87, before `mutate_summary` at line 88
- `cmd_update --apply` replaces stub at lines 174-178 with call to `lib/merge.sh` functions
- `scripts/audit-setup.sh` — add `grep -r '^<<<<<<<' .claude/` check before final
  exit-code block (lines 253-255)
- CI shellcheck glob in `.github/workflows/ci.yml` — add `lib/` to the find pattern
  (per ARCHITECTURE.md)

</code_context>

<specifics>
## Specific Ideas

- Sidecar naming uses path-encoding (underscore-join) specifically to avoid collision
  when multiple skills in different subdirectories both conflict in a single update run
- Exit 1 (not exit 2) for conflicts in `cmd_update --apply` — conflicts are user-resolvable,
  not a hard tool failure; exit 2 reserved for unrecoverable errors (missing deps, missing snapshot)
- Conflict marker detection in `conjure audit` should use `grep -rl '^<<<<<<<' .claude/`
  to find all affected files and report them, not just exit silently

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 09-3-Way Merge*
*Context gathered: 2026-05-25*
