# Architecture Research

**Domain:** Open-source init kit for Claude Code — POSIX bash CLI + Node `.mjs` hooks (Conjure v0.3.0 "Testing + telemetry")
**Researched:** 2026-05-24
**Confidence:** HIGH (existing codebase read directly; integration points verified against real files)

> **Scope note (subsequent milestone):** This file does NOT re-derive Conjure's
> existing architecture. It defines how the five v0.3.0 capabilities slot into
> the *current* file layout — component boundaries, who-writes-what, data flow,
> and a dependency-ordered build sequence. Existing layout taken as fixed:
> `cli/conjure` (dispatcher) → `scripts/*.sh` → `profiles/` `compliance/`
> `migrations/` `templates/`; `tests/run.sh` is the single test entrypoint.

## Standard Architecture

### System Overview — where v0.3.0 work lands

```
┌──────────────────────────────────────────────────────────────────────┐
│  ENTRYPOINTS (existing, lightly extended)                              │
│  ┌────────────────┐         ┌──────────────────┐                      │
│  │  cli/conjure   │         │   tests/run.sh   │                      │
│  │  (dispatcher)  │         │  (test driver)   │                      │
│  └──────┬─────────┘         └─────────┬────────┘                      │
│   init / audit / migrate              │ NEW: per-fixture loop          │
├─────────┼─────────────────────────────┼───────────────────────────────┤
│  WORKER SCRIPTS (existing + new)      │                                │
│  ┌──────▼──────────┐  ┌───────────────▼─────┐  ┌──────────────────┐   │
│  │ init-project.sh │  │  audit-setup.sh     │  │ scripts/preflight│   │
│  │ + DRY_RUN guard │  │  + --cost section   │  │   .sh (NEW,      │   │
│  │                 │  │  + telemetry report │  │   extracted)     │   │
│  └──────┬──────────┘  └──────────┬──────────┘  └──────────────────┘   │
│         │ DRY_RUN threads through │ reads cost model + event log       │
├─────────┼────────────────────────┼────────────────────────────────────┤
│  SHARED LIB (NEW — lib/)         │                                     │
│  ┌──────▼─────────────────┐  ┌───▼──────────────────┐                 │
│  │ lib/mutate.sh          │  │ lib/cost.sh          │                 │
│  │ (write/cp/mkdir guard) │  │ (char→token→$ model) │                 │
│  └────────────────────────┘  └──────────────────────┘                 │
├──────────────────────────────────────────────────────────────────────┤
│  TEMPLATES (shipped into target .claude/)                             │
│  ┌────────────────────────────┐  ┌──────────────────────────────┐    │
│  │ templates/hooks/            │  │ templates/hooks-nodejs/      │    │
│  │  skill-telemetry.sh (NEW)   │  │  skill-telemetry.mjs (NEW)   │    │
│  └─────────────┬───────────────┘  └──────────────┬───────────────┘    │
│                │ writes (in target project)        │                   │
├────────────────┼──────────────────────────────────┼───────────────────┤
│  TARGET PROJECT (runtime, not the kit)            │                   │
│  ┌─────────────▼──────────────────────────────────▼──────────────┐    │
│  │  .claude/telemetry/skill-events.jsonl   (append-only log)      │    │
│  └────────────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────────────┤
│  FIXTURES (NEW — committed test data)                                 │
│  tests/fixtures/<profile>/  +  tests/fixtures/<profile>/EXPECT.txt    │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility (what it owns) | Real path |
|-----------|-------------------------------|-----------|
| `cli/conjure` | Dispatch + flag parsing; pass `--dry-run`/`--cost` down; call `scripts/preflight.sh` | `cli/conjure` (exists) |
| `scripts/preflight.sh` | Dependency verification + one-command install fix-its; reusable by CLI and tests | NEW — extracted from `cmd_preflight()` |
| `lib/mutate.sh` | Single chokepoint for every filesystem write; honors `DRY_RUN`; logs intended mutations | NEW |
| `lib/cost.sh` | Pure functions: chars→tokens→$ estimate, per-skill breakdown | NEW |
| `scripts/init-project.sh` | Scaffold `.claude/`; route all writes through `lib/mutate.sh` | exists — refactor writes |
| `scripts/audit-setup.sh` | Health-check; gains `--cost` block + telemetry "retire-list" report block | exists — extend |
| `templates/hooks/skill-telemetry.sh` (+ `.mjs`) | Runtime hook in target project; appends one event per skill load | NEW templates |
| `tests/fixtures/<profile>/` | Committed example project per stack profile, scaffolded + filled, audited green | NEW |
| `tests/fixtures/<profile>/EXPECT.txt` | Declarative assertion file the runner diffs audit output against | NEW |
| `tests/run.sh` | Adds a per-fixture loop: run audit in each fixture, compare to EXPECT | exists — extend |

**Boundary rule:** The *kit* (this repo) never writes a telemetry log. Only the
*shipped hook running inside a target project* writes `.claude/telemetry/`. The
kit only ships the hook template and reads logs during `audit --cost`/retire
reporting against whatever project it points at. This keeps the kit stateless.

## Recommended Project Structure

```
conjure/
├── cli/
│   └── conjure                      # dispatcher — add --cost route, call scripts/preflight.sh
├── lib/                             # NEW — sourced helpers (not subcommands)
│   ├── mutate.sh                    # write_file / copy_into / make_dir — DRY_RUN-aware
│   └── cost.sh                      # est_tokens(), est_cost(), per_skill_breakdown()
├── scripts/
│   ├── init-project.sh              # refactor: source lib/mutate.sh, replace cp/mkdir/cat>
│   ├── audit-setup.sh               # extend: source lib/cost.sh; add --cost + retire-list blocks
│   ├── preflight.sh                 # NEW — extracted dependency check + fix-its
│   └── ...                          # (refresh-graph, install-mcp-stack unchanged)
├── templates/
│   ├── hooks/
│   │   └── skill-telemetry.sh       # NEW — bash telemetry hook (POSIX)
│   ├── hooks-nodejs/
│   │   └── skill-telemetry.mjs      # NEW — Node telemetry hook (Windows parity)
│   └── settings.json.tmpl           # extend: register telemetry hook (see Data Flow)
└── tests/
    ├── run.sh                       # extend: fixtures loop + dry-run + preflight assertions
    ├── lib/
    │   └── assert.sh                # NEW (optional) — assert_audit_green, assert_no_writes
    └── fixtures/                    # NEW
        ├── python-fastapi/          # one dir per profile
        │   ├── .claude/             # committed, audited-green harness
        │   ├── CLAUDE.md
        │   └── EXPECT.txt           # expected audit signature
        ├── ts-next/
        ├── rust-axum/
        └── ...                      # 9 total
```

### Structure Rationale

- **`lib/` (new top-level):** Conjure currently has only entrypoints (`cli/`) and
  worker scripts (`scripts/`). Telemetry-cost math and the dry-run guard are
  *shared logic* used by both `audit-setup.sh` and `init-project.sh` (and tests).
  A sourced-library dir is the idiomatic bash way to share without forking a
  subprocess. Keep these files non-executable and `source`d, never dispatched.
- **`scripts/preflight.sh` (extracted, not new logic):** `cmd_preflight()` already
  lives inline in `cli/conjure` (lines 169–188). Extracting it to a standalone
  script lets `tests/run.sh` assert on it and lets profile `preflight.sh` scripts
  reuse the same fix-it strings. The CLI then just calls `bash scripts/preflight.sh`.
- **`tests/fixtures/<profile>/`:** Mirrors the existing single-fixture CI job
  (`audit-on-fixture` scaffolds `/tmp/fixture`). v0.3.0 promotes that throwaway
  fixture into committed, per-profile fixtures so audit assertions are
  reproducible and reviewable in PRs — not regenerated each CI run.
- **`EXPECT.txt` beside each fixture:** Declarative golden-file assertions keep
  `tests/run.sh` simple — it diffs normalized audit output against the expected
  PASS/WARN/FAIL signature rather than encoding per-fixture logic in the runner.
- **`.claude/telemetry/skill-events.jsonl` (in target, not kit):** JSON Lines is
  append-only and crash-safe (one event = one line; partial writes are skippable),
  needs no parser to append, and `jq -s` can fold it for the retire-list report.
  This is preferred over the existing prose `EVENT-LOG.md` convention because the
  retire-list needs machine aggregation, not human prose.

## Architectural Patterns

### Pattern 1: Mutation chokepoint (`DRY_RUN` threaded, not re-checked)

**What:** Every filesystem write goes through one of three `lib/mutate.sh`
functions. `--dry-run` is parsed once in `cli/conjure`, exported as `DRY_RUN`,
and the chokepoint decides whether to act or just log "[dry-run] would write X".
**When to use:** Any code path that creates/copies/edits files (init, migrate, profile apply).
**Trade-offs:** One refactor pass through `init-project.sh` now; but eliminates the
class of bug where a new write path forgets to honor `--dry-run`. The flag is
*already* parsed in `cmd_init` (line 56) and passed to migrate/profile apply —
this pattern makes it actually enforced at the write site instead of advisory.

**Example:**
```bash
# lib/mutate.sh
copy_into() {   # copy_into <src> <dst>
  if [ "${DRY_RUN:-0}" = 1 ]; then echo "  [dry-run] would copy → $2"; return 0; fi
  cp -R "$1" "$2"
}
# init-project.sh — before:  cp "$KIT/templates/$f" "$f"
#                   after:   copy_into "$KIT/templates/$f" "$f"
```

### Pattern 2: Telemetry as an append-only event hook (kit ships, project writes)

**What:** A new hook (`skill-telemetry.sh` / `.mjs`) registered in
`settings.json.tmpl` fires when skills load and appends one JSONL event to
`.claude/telemetry/skill-events.jsonl` in the *target* project.
**When to use:** Runtime in any Conjure-initialized project that opts into telemetry.
**Trade-offs:** Claude Code's hook event surface determines fidelity — if no
`SkillLoad`/`UserPromptSubmit`-with-skill event exists, fall back to logging at
`SessionStart`/`Stop` what skills were *available* + which files were read
(coarser signal, still feeds retire-list). **Confidence on exact event name: LOW
— must verify against installed Claude Code ≥2.1.117 hook docs before building.**

**Example (event line, one per skill activation):**
```json
{"ts":"2026-05-24T19:00:00Z","event":"skill_load","skill":"api-routes","session":"abc123"}
```

### Pattern 3: Golden-file fixture assertions (declarative regression)

**What:** Each fixture ships an `EXPECT.txt` capturing the audit summary it must
produce. `tests/run.sh` runs `audit-setup.sh <fixture>`, normalizes output (strip
timestamps/paths), and diffs against `EXPECT.txt`.
**When to use:** Per-profile regression — proves a profile's scaffold stays
audit-green as templates evolve.
**Trade-offs:** Golden files need regeneration when audit output intentionally
changes (add a `tests/update-fixtures.sh` helper). Cheaper than imperative
assertions and gives readable diffs in PRs.

**Example:**
```bash
# tests/run.sh — new block
for fx in tests/fixtures/*/; do
  prof=$(basename "$fx")
  got=$(bash scripts/audit-setup.sh "$fx" 2>&1 | grep -E '^(PASS|WARN|FAIL):' )
  exp=$(cat "$fx/EXPECT.txt")
  [ "$got" = "$exp" ] && pass "fixture audit: $prof" || fail "fixture drift: $prof"
done
```

## Data Flow

### Telemetry flow (session → hook → log → retire-list)

```
Claude Code session in target project
        │ (skill loads / session events fire)
        ▼
.claude/hooks/skill-telemetry.sh   (shipped by init-project.sh)
        │ appends one JSON line
        ▼
.claude/telemetry/skill-events.jsonl   (append-only, in TARGET repo)
        │ read later (not during the session)
        ▼
conjure audit --cost   →  scripts/audit-setup.sh
        │ folds events with `jq -s`, joins against skills present on disk
        ▼
"Retire-list" report block:
  skills with 0 loads in N sessions  →  candidates to retire
  + cost block: harness chars→tokens→$ from lib/cost.sh
```

### Cost-estimate flow (`conjure audit --cost`)

```
conjure audit --cost .
        │ cli/conjure routes --cost → audit-setup.sh (passes flag through)
        ▼
audit-setup.sh sources lib/cost.sh
        │ already computes TOTAL_CHARS for .claude/ (audit-setup.sh:124)
        ▼
lib/cost.sh: est_tokens(chars)=chars/4 ; est_cost(tokens)=tokens * $/Mtok
        │ + per-skill breakdown (which skills cost the most context)
        ▼
prints "Estimated per-session harness load: ~N tokens (~$X.XX at <model rate>)"
```

### Dry-run flow (single parse, threaded enforcement)

```
conjure init --dry-run .        (flag parsed once: cli/conjure:56)
        │ export DRY_RUN=1
        ▼
init-project.sh  →  every write calls lib/mutate.sh helper
        │ DRY_RUN=1 → print "[dry-run] would …", make NO change
        ▼
profile apply.sh / migrate.sh  (already receive dryrun arg)
        │ also route writes through lib/mutate.sh
        ▼
Result: identical console plan, zero filesystem mutations  (assert in tests/run.sh)
```

### Pre-flight flow

```
conjure init / migrate / audit
        │ cli/conjure calls  bash scripts/preflight.sh  (before any mutation)
        ▼
scripts/preflight.sh checks required (git, jq, rg) + optional (graphify, ast-grep…)
        │ missing → prints exact one-command fix-it ("brew install … / apt-get install …")
        ▼
required missing → exit non-zero (block);  optional missing → warn + continue
```

### Key Data Flows (summary)

1. **Skill telemetry:** session → hook → `skill-events.jsonl` → `audit --cost` folds → retire-list. Log lives in the *target* project; the kit only reads it.
2. **Cost:** existing `.claude/` char count (audit already computes it) → `lib/cost.sh` → token + dollar estimate + per-skill breakdown.
3. **Dry-run:** parsed once in CLI → `DRY_RUN` env → enforced at `lib/mutate.sh` chokepoint across init/migrate/profile.
4. **Fixtures:** committed `tests/fixtures/<profile>/` → `audit-setup.sh` → normalized output diffed vs `EXPECT.txt` in `tests/run.sh`.

## Scaling Considerations

*(Reframed for a CLI/test-kit: "scale" = number of profiles, fixtures, and telemetry log growth — not user load.)*

| Scale | Architecture adjustments |
|-------|--------------------------|
| 9 profiles / 9 fixtures (now) | Flat `tests/fixtures/<profile>/`, linear loop in `run.sh` — fine. CI time dominated by 9 audit runs (<seconds each). |
| +compliance overlay fixtures | Add `tests/fixtures/<profile>+<overlay>/` sparingly (combinatorial — pick representative pairs, not all 9×4). |
| Telemetry log growth in a busy project | `skill-events.jsonl` is append-only; add a size/age note in audit ("rotate if >N MB"). Retire-list reads last N sessions, not whole file. |

### Scaling Priorities

1. **First bottleneck:** CI wall-time as fixtures grow — keep audit fast; avoid spawning `graphify`/network in fixture audits (fixtures must be hermetic, offline).
2. **Second bottleneck:** Fixture maintenance burden when audit output format changes — mitigate with a `tests/update-fixtures.sh` regenerator so EXPECT files aren't hand-edited.

## Anti-Patterns

### Anti-Pattern 1: Re-checking `--dry-run` at every call site

**What people do:** Sprinkle `[ "$DRY" = 0 ] && cp …` at each write (the profile
`apply.sh` already does this — see `profiles/python-fastapi/apply.sh`).
**Why it's wrong:** Every new write path is a chance to forget the guard; that's
exactly the "not enforced everywhere" gap the roadmap calls out.
**Do this instead:** Route all writes through `lib/mutate.sh`; the guard lives in one place.

### Anti-Pattern 2: Kit writes telemetry into its own repo

**What people do:** Have `conjure` write an event log under the kit's own tree.
**Why it's wrong:** Conjure is stateless tooling; telemetry is per-*target*-project
data and belongs in that project's `.claude/telemetry/`, gitignored there.
**Do this instead:** Ship the hook; the hook (running in the target) owns the log. Kit only reads.

### Anti-Pattern 3: Imperative per-fixture assertions inside `run.sh`

**What people do:** Hard-code "python-fastapi should have 18 skills, 6 agents…" in the runner.
**Why it's wrong:** Runner balloons; every profile tweak edits shared test code.
**Do this instead:** Golden `EXPECT.txt` per fixture; runner stays a generic diff loop.

### Anti-Pattern 4: Non-hermetic fixtures

**What people do:** Fixture audit invokes `graphify`, `git`, or network during CI.
**Why it's wrong:** Flaky CI; `audit-setup.sh` already conditionals on `graphify-out/`
and `git` — fixtures must omit those so the audit signature is deterministic.
**Do this instead:** Commit fixtures with no `graphify-out/`, stub git state; assert only on deterministic blocks.

## Integration Points

### External tools

| Tool | Integration pattern | Notes |
|------|---------------------|-------|
| Claude Code hooks | `settings.json.tmpl` registers `skill-telemetry.{sh,mjs}` | **Verify the exact skill-load hook event name vs CC ≥2.1.117 before building** — telemetry fidelity depends on it. |
| `jq` | Fold `skill-events.jsonl` for retire-list; already a preflight dep | Audit already gates on `jq` presence (`audit-setup.sh:86`). |
| `shellcheck` (CI) | New `lib/*.sh` + `scripts/preflight.sh` join the lint glob | Update CI find-glob in `.github/workflows/ci.yml` to include `lib`. |

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `cli/conjure` ↔ `scripts/*` | subprocess (`bash …`) + args/env | Existing pattern; `--cost`/`DRY_RUN` flow as arg/env. |
| `scripts/*` ↔ `lib/*` | `source` (same process) | New; lib functions need caller's vars (`DRY_RUN`, paths). |
| hook (target) ↔ telemetry log | append to file in target `.claude/` | One-directional write; kit never writes here. |
| `tests/run.sh` ↔ fixtures | `audit-setup.sh <fixture>` + diff `EXPECT.txt` | Generic loop, declarative expectations. |

## Suggested Build Order (dependency-driven)

Ordered so each phase unblocks the next; maps to roadmap phases under v0.3.0.

1. **Pre-flight extraction** (`scripts/preflight.sh`) — smallest, standalone;
   immediately testable; the fix-it strings are reused by later phases. No deps.
2. **`lib/mutate.sh` + dry-run enforcement** — refactor `init-project.sh` writes
   through the chokepoint. Independent of telemetry/cost. Unblocks safe fixture
   generation (you want `--dry-run` correct before you trust generated fixtures).
3. **Test fixtures per profile** (`tests/fixtures/<profile>/` + `EXPECT.txt`) —
   depends on a trustworthy `init` (steps 1–2) so generated fixtures are correct.
   Generate via `conjure init --profile=X`, fill CLAUDE.md, audit green, snapshot.
4. **Regression suite wiring** (`tests/run.sh` fixture loop) — depends on fixtures
   (3) existing. Adds golden-file diff loop + dry-run assertion (asserts step 2).
5. **`lib/cost.sh` + `audit --cost`** — depends only on audit's existing char
   count; can proceed in parallel with 3–4, but fixtures (3) give it test targets.
6. **Skill telemetry hook** (`templates/hooks/skill-telemetry.{sh,mjs}` + settings
   registration) — last, because (a) it needs the CC hook-event verification, and
   (b) the retire-list report it feeds plugs into the now-extended `audit --cost`
   (step 5) and is best validated against fixtures (step 3) carrying sample logs.

**Why this order:** safety primitives (preflight, dry-run) first → trustworthy
fixtures → regression net that guards everything after → analytical features
(cost, telemetry) last, since they consume the fixtures and the extended audit.

## Sources

- `cli/conjure`, `scripts/init-project.sh`, `scripts/audit-setup.sh`, `tests/run.sh`, `templates/settings.json.tmpl`, `templates/hooks/*`, `profiles/python-fastapi/{apply,preflight}.sh`, `.github/workflows/ci.yml` — read directly this session (HIGH confidence).
- `.planning/PROJECT.md`, `planning/ROADMAP.md`, `planning/GSD-INTEGRATION.md` — v0.3.0 scope + constraints (HIGH).
- Claude Code hook event surface (skill-load event name) — NOT verified this session; **flag for phase-time verification** against installed CC ≥2.1.117 docs (LOW until confirmed).

---
*Architecture research for: Conjure v0.3.0 testing + telemetry integration*
*Researched: 2026-05-24*
