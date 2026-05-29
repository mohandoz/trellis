# Phase 22: `conjure adopt` CLI Core + Rollback - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire the Phase 21 primitives (`lib/snapshot.sh`, `lib/inventory.sh`,
`lib/log.sh`, `lib/caps.sh` + `mutate_archive`) into a complete, audited,
rollback-capable adoption pipeline that a user runs with one command on an
existing repo:

- `scripts/adopt.sh` — the 5-step pipeline orchestrator: **preconditions →
  snapshot → inventory → scaffold → audit**
- `cmd_adopt` in `cli/conjure` — dispatch + arg parsing
- Flags: `--dry-run`, `--force`, `--rollback`, `--apply-step <id>`,
  `--update-manifest`, `--resume`, `--start-fresh` (+ `--full-inventory`
  passthrough to `inventory_scan`)
- `.conjure-adopt-state` step-completion manifest (path + sha256 before/after)
- Signal traps (INT/TERM → exit 2) and partial-run recovery prompt
- `--rollback` restore + adoption report

**Requirements:** ADOPT-01, ADOPT-02, ADOPT-04, ADOPT-05, ADOPT-06, SAFE-01,
SAFE-02, SAFE-04, SAFE-05, SAFE-06, SAFE-07.

**Not this phase:** the `restructure` skill itself (Phase 23 — Phase 22 only
ships the `--apply-step`/`--update-manifest` *executor* the skill will drive),
integration tests + Argus fixture (Phase 24). Inventory/classification logic,
caps, snapshot lib, log lib, and `mutate_archive` are **already built and
tested in Phase 21** — do not reimplement; orchestrate them.

</domain>

<decisions>
## Implementation Decisions

### Rollback scope & cleanliness (SAFE-02, Phase 24 zero-diff)
- **D-01:** `--rollback` = **full restore + delete-created**. Three steps: (1)
  `snapshot_rollback` does whole-tree `cp -a snapshot/. target/` (restores every
  mutated file AND un-archives originals, since both live in the snapshot); (2)
  for each path in `.conjure-adopt-state` `created[]`, `mutate_rm` it (removes
  scaffolded harness files the snapshot can't undo); (3) verify
  `sha256(p) == before` for every `p` in `mutated[]`. Then `log_step ROLLBACK`.
  This is the only strategy that yields Phase 24's sha256-identical before/after.
  Surgical (manifest-only restore) and full-restore-only were **rejected** —
  the former risks unrecorded mutations escaping, the latter leaves scaffolded
  files behind.
- **D-02:** `created[]` tracks **scaffolded harness paths only** (new
  skills/agents/hooks/docs). It does **NOT** include conjure's own backup
  infrastructure (`.conjure-adopt-backups/`, `.conjure-archive-<ts>/`,
  `.conjure-adopt-state`, `RESTRUCTURE-LOG.md`) — those are never deleted by the
  delete-created step.
- **D-03:** Phase 24's "zero diff after rollback" comparison **MUST exclude
  conjure's own dirs** (`.conjure-adopt-backups/`, `.conjure-archive-*`,
  `RESTRUCTURE-LOG.md`) — they didn't exist pre-adopt, so they are out of the
  before/after diff scope. (Flag this to the Phase 24 test author.)
- **D-04:** After a successful rollback, **keep the snapshot dir, archive dir,
  and `RESTRUCTURE-LOG.md`** (now carrying a `[ROLLBACK]` entry) for
  audit/forensics; **delete only `.conjure-adopt-state`** (the run is over — a
  stale state file would trigger a false recovery prompt on the next run). User
  can manually purge backups later. "Remove everything" rejected (destroys the
  audit trail + the only backup right after a restore).

### `--apply-step` / `--update-manifest` contract (the Phase 23 skill seam)
- **D-05:** **Manifest-driven restructure-op executor.** `--apply-step <id>`
  reads operation `#id` from `adopt-manifest.json` `restructure_steps[]`,
  executes it via the appropriate `mutate_*` primitive, `log_step RESTRUCTURE`,
  and marks the step `status: applied`. **Skill proposes (writes manifest), CLI
  applies (reads manifest)** — this preserves the RESTR-02 chokepoint (the skill
  never calls Write/Edit on project files; every mutation routes through
  `lib/mutate.sh`). Pipeline-step-rerun semantics were **rejected** for
  `--apply-step` (doesn't give the skill per-op application).
- **D-06:** `--update-manifest` is how the skill writes **proposed ops + their
  status** back into `adopt-manifest.json` `restructure_steps[]`. This is the
  inbound half of the contract; `--apply-step` is the outbound half.
- **D-07:** **Staging-path content references.** Generated content (condensed
  CLAUDE.md, new SKILL.md bodies) is written by the skill to
  `.conjure-adopt-state/staging/<file>`; the manifest op references it as
  `{ op: "write", dest: "CLAUDE.md", src: ".conjure-adopt-state/staging/CLAUDE.md", status: "proposed" }`.
  Keeps the manifest lean (preserves the INV-02 contract size) and lets
  `--apply-step` + `conjure audit` inspect proposed content as a **real file
  before writing** (sets up RESTR-05's pre-write audit gate). Inline content in
  the manifest **rejected** (bloats JSON, complicates `jq`/audit).
- **D-08:** **Phase 22 scope for the executor:** ship `--apply-step` +
  `--update-manifest` with the supported op types (at least `archive`, `write`;
  `extract` = write-new + archive-old composed from the two) and test them
  against a **synthetic/hand-authored manifest fixture**. Phase 23 wires the
  actual skill that *generates* real ops. Roadmap explicitly makes Phase 23
  depend on this flag pair "working and tested."

### Adoption report + dry-run output (ADOPT-06, ADOPT-02, criterion 1)
- **D-09:** **Report format = labeled plain-text sections + a compact
  before/after delta block** (echo lines, no new deps), consistent with
  existing `cmd_audit` / `cmd_check` output style. Required metrics (fixed by
  ADOPT-06): files inventoried, layers scaffolded, files archived, CLAUDE.md
  line-count delta, snapshot path, audit before→after. Aligned-table format
  rejected (new style, cross-platform alignment fragility).
- **D-10:** **Dry-run runs read-only steps for real.** `--dry-run` executes
  preconditions (git-clean check) + `inventory_scan` (read-only) for real,
  writes `adopt-manifest.json` so the plan is concrete (real counts: N
  inventoried, M missing layers, K cap violations); mutating steps (snapshot,
  scaffold, archive, audit-writes) print `[dry-run] would …`. Static-plan
  rejected (criterion 1 requires an inspectable manifest with real numbers).
- **D-11:** **Dry-run manifest temp path is OUTSIDE the target repo.** Write it
  to a `mktemp -d` system temp dir (e.g. `$TMPDIR`), NOT under
  `.conjure-adopt-state/` or anywhere inside the target — ADOPT-02 ("zero
  filesystem side-effects") and Phase 24 criterion 1 ("writes **zero files to
  the fixture directory**") forbid any write under the target root. Print the
  temp path so the user can inspect the plan. *(This corrects the in-repo
  `.conjure-adopt-state/dry-run/` path shown in the discussion preview — the
  binding constraint is zero writes to the target.)*

### Partial-run recovery (SAFE-04, SAFE-05)
- **D-12:** **`[c]ontinue` = resume at next incomplete step.** Read
  `.conjure-adopt-state` step-completion records, skip steps already marked done
  (sha256-matched), resume at the first incomplete step, and **reuse the
  existing snapshot dir** (no second backup). Restart-from-step-1 rejected
  (creates a duplicate snapshot, re-scans inventory).
- **D-13:** **No-TTY behavior = `exit 2` + explicit recovery flags.** Mirror
  `scripts/resolve.sh`: read the `[r]ollback/[c]ontinue/[s]tart-fresh` prompt
  from `/dev/tty`; if there is no TTY, print the detected partial state
  (including `last completed: <step>`) + instructions and `exit 2` — **never
  auto-mutate**. CI / automation drives recovery non-interactively via explicit
  flags: `--rollback` (undo), `--resume` (= continue, D-12), `--start-fresh`
  (discard state, snapshot anew). Auto-rollback / auto-continue in non-TTY both
  rejected (mutating without consent breaks the trust model). Consistent with
  ADOPT-03's exit-2-on-dirty-tree precedent.
- **D-14:** Interactive recovery prompt has **no default choice** — empty input
  re-prompts (resolve.sh pattern). Recovery is destructive-adjacent; force a
  conscious selection.

### SAFE-06 (git-state warning)
- **D-15:** `snapshot_create` already captures `git_head` + `git_stash_list`
  into `.snapshot-meta.json` (Phase 21). Phase 22's remaining SAFE-06 work is
  the **user-facing warning** that `--rollback` restores from the **filesystem
  snapshot, not git** — surfaced in the report and/or at rollback time.

### Claude's Discretion
- `.conjure-adopt-state` exact JSON schema (step records with path + sha256
  before/after per SAFE-04; `created[]`, `mutated[]`, `staging/` layout) — design
  it during planning, mirroring the `adopt-manifest.schema.json` draft-07 style
  and the `.snapshot-meta.json` shape.
- **Scaffold reuse mechanism** (ADOPT-04): call `scripts/init-project.sh` as a
  subprocess vs. inline its skip-if-exists logic — Phase 21 `code_context`
  already notes `init-project.sh` is "called as subprocesses by the later
  adopt.sh". Default to subprocess unless planning finds a blocker. "Missing
  layer" granularity (file-level vs layer-level) is implementation detail; reuse
  init's existing idempotent never-overwrite behavior.
- Signal-trap mechanics (`trap '…' INT TERM`, ensuring partial state is flushed
  before exit 2), per-step `log_step` message wording, and the exact
  step-ordering of state-record writes (record completion *before* advancing).
- `--force` interaction with recovery: `--force` governs the dirty-tree
  precondition (ADOPT-03); it is independent of the recovery prompt. Confirm no
  surprising overlap during planning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap (this phase)
- `.planning/REQUIREMENTS.md` — ADOPT-01/02/04/05/06, SAFE-01/02/04/05/06/07
  (the 11 requirements this phase satisfies); ADOPT-03/SAFE-03/INV-01..04
  already complete in Phase 21
- `.planning/ROADMAP.md` §"Phase 22: `conjure adopt` CLI Core + Rollback" — goal
  + 5 success criteria (dry-run plan, clean-tree run, dirty-tree/`--force`,
  rollback sha256, SIGKILL recovery)

### Prior phase context (read — defines the primitives being orchestrated)
- `.planning/phases/21-foundation-libs-inventory/21-CONTEXT.md` — D-01..D-13:
  6-bucket taxonomy, manifest schema decisions, `mutate_archive` move-safety
  (copy→verify→rm→ledger), 500-file cap semantics, snapshot raw-`cp` exception

### Research (v0.6.0 — read before planning)
- `.planning/research/SUMMARY.md` — build order, CR-1..7 pitfalls, Open Questions
- `.planning/research/ARCHITECTURE.md` — component boundaries + build order;
  §3 manifest schema (note Phase 21 D-01/D-09 overrides)
- `.planning/research/STACK.md` — POSIX primitives, zero-new-deps envelope
- `.planning/research/PITFALLS.md` — **CR-4 (archive ≠ rollback)** is directly
  relevant to D-01; M-4 (UTC timestamps, quote-safe paths, `cp -a` vs `cp -r`)

### Existing code to extend / mirror
- `cli/conjure` — `cmd_*` dispatch + arg-parse pattern (`case "$1" in … --dry-run)`),
  the `case "${1:-help}" in … adopt) shift; cmd_adopt "$@"` router at the bottom;
  `cmd_resolve` / `cmd_update` show multi-step command structure
- `lib/snapshot.sh` — `snapshot_create` (writes `.snapshot-meta.json` w/ git
  state — SAFE-06 capture), `snapshot_rollback` (whole-tree `cp -a`),
  `snapshot_list`
- `lib/inventory.sh` — `inventory_scan` + `inventory_emit_manifest` (the
  read-only step adopt drives)
- `lib/log.sh` — `log_init` / `log_step` / `log_fail` (RESTRUCTURE-LOG.md writer,
  SAFE-07) — set `RESTRUCTURE_LOG_PATH` so snapshot/inventory auto-log
- `lib/mutate.sh` — `mutate_mkdir/cp/write/rm/archive` + `mutate_summary` +
  `CONJURE_DRY_MUTATION_COUNT`; the chokepoint all `--apply-step` ops route through
- `lib/caps.sh` — cap constants for the audit step
- `scripts/resolve.sh` — **the TTY-prompt model to mirror for recovery**:
  `/dev/tty` read, fd-3 tmpfile trick, `exit 2` on non-TTY (lines ~39-77)
- `scripts/init-project.sh` — the idempotent scaffold subprocess for ADOPT-04
- `scripts/audit-setup.sh` — the audit step subprocess for ADOPT-05 (already
  sources `lib/caps.sh`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 21 libs are the pipeline body** — `scripts/adopt.sh` is mostly glue:
  `log_init` → preconditions (`git status --porcelain`) → `snapshot_create` →
  `inventory_scan`/`inventory_emit_manifest` → scaffold (`init-project.sh`) →
  audit (`audit-setup.sh`) → report. Each `mutate_*` already honors `DRY_RUN`.
- `snapshot_create` already records git HEAD + stash list → SAFE-06 capture is
  done; only the user-facing warning remains (D-15).
- `cmd_resolve` + `scripts/resolve.sh` are the template for the recovery
  prompt's TTY handling and exit-2-on-non-TTY behavior (D-13).

### Established Patterns
- **All filesystem mutations route through `lib/mutate.sh`** (locked v0.3.0) —
  `--apply-step` ops and scaffold writes comply; snapshot is the deliberate raw-`cp`
  exception (must NOT route through `mutate_cp`, or DRY_RUN would suppress the backup).
- **POSIX bash 3.2+**: no associative arrays, no `mapfile`, no `local -n`;
  newline-delimited internal state.
- **Hooks/CLI `exit 2`, never `exit 1`** — recovery non-TTY and dirty-tree
  refusals use exit 2 (D-13, ADOPT-03).
- **Split responsibility (v0.6.0):** CLI = deterministic filesystem + bucketing
  + op execution; skill (Phase 23) = judgment (which ops to propose). D-05
  enforces this — CLI applies ops it's told; it doesn't decide them.

### Integration Points
- `adopt-manifest.json` — Phase 21 finalized its schema (incl. `restructure_steps[]`,
  empty at inventory time). Phase 22 makes `restructure_steps[]` **read+write**:
  `--update-manifest` writes proposals, `--apply-step` consumes them.
- `.conjure-adopt-state` (new this phase) — step-completion manifest (SAFE-04);
  drives recovery (D-12) and rollback `created[]`/`mutated[]` (D-01). Distinct
  from `.snapshot-meta.json` (snapshot identity/git state) and the archive
  ledger (never-delete record) — three separate files, three purposes.
- `cli/conjure` router — add `adopt) shift; cmd_adopt "$@" ;;` to the bottom
  `case` and an entry in `usage()`.

</code_context>

<specifics>
## Specific Ideas

- **Dry-run plan output shape** (illustrative, from discussion):
  ```
  Plan (dry-run — zero writes to repo):
   1. preconditions: git clean ✓
   2. snapshot: [dry-run] would back up → ...
   3. inventory: 142 files → manifest at <mktemp temp path>
   4. scaffold: would create hooks(5), agents(2)
   5. audit: would run audit-setup.sh
  Manifest written for inspection (<temp path>).
  ```
- **Adoption report shape** (illustrative): labeled sections — Inventory /
  Scaffolded / Archived / CLAUDE.md (before→after) / Snapshot / Audit (before→after)
  / Next-step pointer to the restructure skill.
- **No-TTY recovery output** (illustrative): print `last completed: <step>` +
  the three `--rollback`/`--resume`/`--start-fresh` flags, then `exit 2`.

</specifics>

<deferred>
## Deferred Ideas

- `--json` report/inventory output for CI — already tracked as **ADOPT-07 (v2)**.
- `--quick` inventory mode — already tracked as **ADOPT-08 (v2)**.
- The `restructure` skill that *generates* `restructure_steps[]` ops, the
  constraint-extraction pre-pass, and the pre-write audit gate — **Phase 23**
  (Phase 22 only builds the executor + staging contract they ride on).

None expanded Phase 22 scope — discussion stayed within the phase boundary.

</deferred>

---

*Phase: 22-conjure-adopt-cli-core-rollback*
*Context gathered: 2026-05-28*
