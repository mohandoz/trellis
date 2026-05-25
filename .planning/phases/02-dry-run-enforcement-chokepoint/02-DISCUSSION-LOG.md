# Phase 2: Dry-Run Enforcement Chokepoint - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-24
**Phase:** 02-dry-run-enforcement-chokepoint
**Areas discussed:** mutate.sh interface, Dry-run output format, Compliance overlay scope

---

## mutate.sh interface

### Q1: How should scripts call lib/mutate.sh?

| Option | Description | Selected |
|--------|-------------|----------|
| Sourced library | Scripts `source "$LIB/mutate.sh"` then call `mutate_cp`, `mutate_mkdir`, `mutate_write`. No subprocess overhead. | ✓ |
| Standalone wrapper script | Scripts call `bash "$LIB/mutate.sh" cp src dst`. Forks a subprocess per write. | |

**User's choice:** Sourced library
**Notes:** Consistent with bash conventions, avoids subprocess overhead across ~12 calls in init-project.sh.

### Q2: What functions should lib/mutate.sh expose?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal set: mutate_mkdir, mutate_cp, mutate_write | Covers all actual call sites. Small and auditable. | ✓ |
| Full POSIX mirror | Adds mutate_mv, mutate_rm, mutate_chmod. Future-proofs but adds untested paths. | |

**User's choice:** Minimal set
**Notes:** Only build what Phase 2 needs. Three operations cover all actual write sites.

### Q3: Where does DRY_RUN state live at call time?

| Option | Description | Selected |
|--------|-------------|----------|
| Env var DRY_RUN | CLI exports DRY_RUN=1; lib/mutate.sh reads it. Consistent with migrations pattern (cli/conjure:107). | ✓ |
| Global bash variable set after source | Caller sets CONJURE_DRY_RUN=1 then sources. Requires every script to set it. | |

**User's choice:** Env var DRY_RUN
**Notes:** Migrations already use this pattern. No new convention needed.

---

## Dry-run output format

### Q1: What prefix should each suppressed mutation print?

| Option | Description | Selected |
|--------|-------------|----------|
| [dry-run] would \<op\> \<args\> | Machine-readable prefix. Phase 4 golden-file tests can grep for it. | ✓ |
| ⊘ \<op\> \<args\> | Symbol prefix. Compact but harder to grep. | |
| indent + skip: | Indented label. Blends with CLI output style. | |

**User's choice:** `[dry-run] would <op> <args>`
**Notes:** Locked for Phase 4 golden-file assertions. Use exact string `[dry-run]`, no variants.

### Q2: Should dry-run output show a summary at the end?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — print mutation count | `[dry-run] N mutations skipped — run without --dry-run to apply` | ✓ |
| No — per-line output only | Each [dry-run] line is self-evident. Simpler. | |

**User's choice:** Yes — summary at end
**Notes:** Confirms the flag worked. Count accumulated via `CONJURE_DRY_MUTATION_COUNT`.

---

## Compliance overlay scope

### Q1: Should compliance/*/apply.sh get lib/mutate.sh treatment in Phase 2?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — include all compliance overlays | SAFE-02 says "all writes". Phase 2 completes the chokepoint fully. | ✓ |
| No — defer to later phase | Not called by conjure init; doesn't violate Phase 2 success criteria. | |

**User's choice:** Yes — include all 4 compliance overlays
**Notes:** Even though not invoked by `conjure init` today, they mutate files directly and must respect DRY_RUN per SAFE-02.

### Q2: How should compliance apply.sh pass DRY_RUN to lib/mutate.sh?

| Option | Description | Selected |
|--------|-------------|----------|
| Inherit env var DRY_RUN | Caller exports; compliance script sources lib. No signature change. | ✓ |
| Add DRY_RUN as $2 argument | Explicit arg. But profiles already use $2 for DRY — mixed convention. | |

**User's choice:** Inherit env var
**Notes:** Env var inheritance keeps all scripts consistent. No apply.sh signatures change.

---

## Claude's Discretion

- `$LIB` resolution path inside scripts — use `$CONJURE_HOME/lib/mutate.sh`.
- `mutate_write` content passing for multi-line vs single-line.
- Minimum bash version compatibility for `lib/mutate.sh`.

## Deferred Ideas

None — discussion stayed within phase scope.
