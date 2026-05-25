---
phase: 02-dry-run-enforcement-chokepoint
plan: "02"
subsystem: init
tags: [bash, dry-run, mutation-chokepoint, posix, init-project]

# Dependency graph
requires:
  - "lib/mutate.sh (02-01): mutate_mkdir, mutate_cp, mutate_write, mutate_summary functions"
provides:
  - "scripts/init-project.sh: all 12 bare write sites routed through lib/mutate.sh"
  - "SAFE-01 chokepoint: DRY_RUN=1 leaves target tree completely unchanged"
affects:
  - 02-05  # cli/conjure cmd_init wiring (threads DRY_RUN env var to init-project.sh)
  - 02-06  # integration test (verifies SAFE-01 via cli/conjure init --dry-run)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Brace-expansion expansion: mkdir .claude/{a,b,c} split into 4 explicit mutate_mkdir calls"
    - "Variable-capture heredoc: content assigned to var then passed to mutate_write — avoids subshell counter loss"
    - "source CONJURE_HOME/lib/mutate.sh: absolute path via CONJURE_HOME per D-03"

key-files:
  created: []
  modified:
    - scripts/init-project.sh

key-decisions:
  - "Variable-capture over heredoc for .env.example: heredoc cat > creates a subshell which would lose CONJURE_DRY_MUTATION_COUNT; assigning to ENV_CONTENT variable and passing to mutate_write keeps the counter in the current shell"
  - "Explicit if block for COMPOUND-CANDIDATES.md write: replaced single-line || shortcircuit with explicit if [ ! -f ] block for clarity and mutate_write compatibility"
  - "mutate_summary placed before cat <<EOF next-steps banner: ensures mutation count is always printed before informational output in dry-run mode"

# Metrics
duration: 3min
completed: 2026-05-24
---

# Phase 2 Plan 02: Retrofit scripts/init-project.sh (12 write sites) Summary

**All 12 bare filesystem write operations in scripts/init-project.sh routed through lib/mutate.sh; DRY_RUN=1 prints 45 [dry-run] lines and creates zero filesystem artifacts (SAFE-01 verified)**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-24T20:11:42Z
- **Completed:** 2026-05-24T20:14:44Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `source "$CONJURE_HOME/lib/mutate.sh"` after KIT= line per D-03 (absolute path, not relative)
- Replaced brace-expansion `mkdir -p .claude/{skills,agents,hooks,docs}` with 4 explicit `mutate_mkdir` calls (Pitfall 2 — brace expansion cannot pass through function arguments)
- Replaced all `cp` / `cp -r` calls with `mutate_cp` (function auto-detects -r via `[ -d "$1" ]`)
- Replaced `mkdir -p docs/adr` with `mutate_mkdir "docs/adr"`
- Replaced heredoc `cat >.env.example <<'EOF'` with variable-capture + `mutate_write` (Pitfall 3 — pipe/heredoc creates subshell and loses counter)
- Replaced single-line `|| echo ... > file` with explicit if block + `mutate_write`
- Added `mutate_summary` call before next-steps banner (prints mutation count when DRY_RUN=1)
- All 121 existing tests pass (no regressions)
- SAFE-01 verified: `DRY_RUN=1` run produces 45 mutations reported, zero filesystem changes

## Task Commits

1. **Task 1: Add lib/mutate.sh source line** - `fba4a1c` (feat)
2. **Task 2: Replace all 12 bare write sites** - `0f5bbad` (feat)

## Files Created/Modified

- `scripts/init-project.sh` — All 12 bare filesystem writes (mkdir/cp/cat>/echo>) replaced by mutate_mkdir/mutate_cp/mutate_write calls; source line added; mutate_summary at tail; DRY_RUN=1 suppresses all mutations while printing [dry-run] prefix lines; CONJURE_DRY_MUTATION_COUNT accumulates to 45 mutations in full run

## Decisions Made

1. **Variable-capture pattern for heredoc content** — The `.env.example` heredoc (`cat >.env.example <<'EOF'`) was replaced with a variable assignment (`ENV_CONTENT='...'`) then `mutate_write ".env.example" "$ENV_CONTENT"`. A heredoc redirect opens a subshell in the writing process, which would have a separate copy of `CONJURE_DRY_MUTATION_COUNT` and changes to the counter inside would be lost when the subshell exits.

2. **Explicit if block for COMPOUND-CANDIDATES.md** — The single-line `[ -f .claude/COMPOUND-CANDIDATES.md ] || echo "..." > file` construct was expanded to an explicit `if [ ! -f ... ]; then mutate_write ...; fi` block. This is clearer and correctly passes content as a string argument (not a redirect).

3. **mutate_summary before informational cat <<EOF** — Placed immediately before the next-steps banner so dry-run users see the mutation count as the final operational output, before decorative content.

## Deviations from Plan

None — plan executed exactly as written. All replacements applied in a single write pass per Task 2 instructions. Both pitfalls (brace expansion, subshell counter loss) handled as documented in RESEARCH.md and PATTERNS.md.

## Known Stubs

None — all write sites are wired to real mutate_* functions.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-02-05 mitigated | scripts/init-project.sh | ENV_CONTENT is static hardcoded string (not user-supplied); printf '%s\n' in mutate_write prevents shell metacharacter execution |

## Self-Check: PASSED

- `scripts/init-project.sh` exists and has `source.*lib/mutate.sh` (1 occurrence)
- Commits fba4a1c and 0f5bbad verified in git log
- `bash -n scripts/init-project.sh` exits 0
- `DRY_RUN=1` run: 46 `[dry-run]` lines, zero filesystem artifacts, 45 mutations reported
- `bash tests/run.sh`: PASS 121, FAIL 0
