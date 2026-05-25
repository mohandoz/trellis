# Phase 2: Dry-Run Enforcement Chokepoint - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `lib/mutate.sh` — a sourced bash library that wraps every filesystem write
(`mkdir`, `cp`, `write`) — and retrofit all write sites so `DRY_RUN=1` suppresses
mutations everywhere from one chokepoint.

Write sites in scope: `scripts/init-project.sh` (~12 bare write calls), the
`.conjure-version` stamp in `cli/conjure:84`, `profiles/*/apply.sh` (9 profiles),
and `compliance/*/apply.sh` (4 overlays: hipaa, gdpr, soc2, pci).

Deliverables: `lib/mutate.sh` (new), updated write sites across init + profiles +
compliance, end-to-end test assertion that `conjure init --dry-run` leaves the
target tree unchanged.

</domain>

<decisions>
## Implementation Decisions

### lib/mutate.sh Interface
- **D-01:** `lib/mutate.sh` is a **sourced library**, not a standalone script. Scripts do `source "$LIB/mutate.sh"` at the top, then call `mutate_cp`, `mutate_mkdir`, `mutate_write`.
- **D-02:** Expose **minimal function set**: `mutate_mkdir`, `mutate_cp`, `mutate_write`. Covers all actual call sites. No future-proofing (no `mutate_mv`, `mutate_rm`, `mutate_chmod`).
- **D-03:** `DRY_RUN` is an **env var** read by `lib/mutate.sh`. The CLI already exports `DRY_RUN="$dryrun"` for migrations (line 107); extend the same pattern to `init-project.sh` and all apply scripts. No argument threading required.

### Dry-Run Output Format
- **D-04:** Each suppressed mutation prints: `[dry-run] would <op> <args>`
  - Example: `[dry-run] would mkdir .claude/skills`
  - Example: `[dry-run] would cp templates/settings.json.tmpl .claude/settings.json`
  - Searchable/greppable prefix — Phase 4 golden-file tests can assert exact output.
- **D-05:** Print a **summary line at end** of each script's run:
  `[dry-run] N mutations skipped — run without --dry-run to apply`
  Count is accumulated by `lib/mutate.sh` via a `CONJURE_DRY_MUTATION_COUNT` env/global.

### Compliance Overlay Scope
- **D-06:** All 4 compliance overlays (`compliance/hipaa`, `compliance/gdpr`, `compliance/soc2`, `compliance/pci`) are **included in Phase 2**. SAFE-02 requires "all writes" and these scripts mutate files directly. DRY_RUN flows via env var inheritance — no signature change to `apply.sh` needed.
- **D-07:** Compliance scripts currently not called by `conjure init`, but they must respect `DRY_RUN` when invoked by users. Phase 2 closes the gap everywhere.

### Claude's Discretion
- Exact `$LIB` resolution path inside scripts (e.g., `$(dirname "$0")/../lib/mutate.sh` vs `$CONJURE_HOME/lib/mutate.sh`). Use `$CONJURE_HOME/lib/mutate.sh` — it's already the established pattern for script cross-references.
- Whether `mutate_write` takes content as a bash heredoc arg or writes via stdin pipe. Use stdin pipe for multi-line content (`printf '%s' "$content" | mutate_write "$dest"`), positional arg for single-line (e.g., version stamp).
- Exact minimum bash version for `lib/mutate.sh` (must match POSIX bash 3.2+ constraint from Phase 1).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Safety & Cross-Platform — SAFE-01, SAFE-02 (the two requirements this phase addresses)
- `.planning/ROADMAP.md` §Phase 2 — Goal, success criteria, and phase boundary

### Existing Code to Modify
- `cli/conjure:75` — `bash "$CONJURE_HOME/scripts/init-project.sh" "$mode" "$target"` — add `DRY_RUN="$dryrun"` export to this call
- `cli/conjure:84` — `echo "$CONJURE_VERSION" > "$target/.claude/.conjure-version"` — inline write in `cmd_init`, must go through `mutate_write`
- `scripts/init-project.sh` — ~12 bare `mkdir`/`cp`/`cat >` calls, zero dry-run; retrofit all to use `lib/mutate.sh`
- `profiles/ts-next/apply.sh` (and all 8 other profiles) — currently use ad-hoc `[ "$DRY" = 0 ]` checks; replace with `lib/mutate.sh` functions
- `compliance/hipaa/apply.sh`, `compliance/gdpr/apply.sh`, `compliance/soc2/apply.sh`, `compliance/pci/apply.sh` — no dry-run at all; add `source` + replace bare writes

### New File to Create
- `lib/mutate.sh` — new file; `lib/` directory does not exist yet

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cli/conjure:107` — `CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" bash "$script" "$target"` — established env-var threading pattern for migrations; reuse for init-project.sh.
- `profiles/ts-next/apply.sh:10` — existing `[ "$DRY" = 0 ]` dry-run guard; shows the shape before lib migration.
- `scripts/preflight.sh` (Phase 1 output) — example of a POSIX bash 3.2+ library/script that other callers invoke; follow same style.

### Established Patterns
- All hooks use `exit 2` to block (never `exit 1`) — mutation failures in `lib/mutate.sh` should follow same convention.
- `cli/conjure` uses `set -uo pipefail` — `lib/mutate.sh` must be safe to source inside `set -u` contexts (no unbound variable reads).
- Profiles take `$TARGET` as `$1` and `$DRY` as `$2` — Phase 2 migrates the dry-run check from `$2` arg to `$DRY_RUN` env var for consistency.

### Integration Points
- `lib/mutate.sh` sourced by: `scripts/init-project.sh`, all `profiles/*/apply.sh`, all `compliance/*/apply.sh`, and inline in `cli/conjure` for the version stamp.
- `CONJURE_HOME` env var already set by CLI before calling child scripts — use it to resolve `$CONJURE_HOME/lib/mutate.sh` in all sourcing scripts.
- Phase 4 regression suite will assert `[dry-run]` prefixed lines appear and mutation count > 0 on `conjure init --dry-run` — format locked in D-04/D-05.

</code_context>

<specifics>
## Specific Ideas

- The existing `DRY_RUN="$dryrun"` in `cmd_migrate` (cli/conjure:107) is the template for how CLI should pass dry-run to `init-project.sh`. Apply the same pattern.
- `CONJURE_DRY_MUTATION_COUNT` counter in `lib/mutate.sh` lets scripts accumulate across multiple calls and print a single summary at script exit — cleaner than per-file counting.
- Phase 4 golden-file tests will grep for `[dry-run]` prefix — use this exact string, no variants.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Dry-Run Enforcement Chokepoint*
*Context gathered: 2026-05-24*
