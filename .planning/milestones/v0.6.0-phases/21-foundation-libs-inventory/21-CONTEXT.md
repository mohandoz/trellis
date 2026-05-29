# Phase 21: Foundation Libs + Inventory - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the shared library layer and the inventory contract that every later
v0.6.0 component depends on, each independently testable:

- `lib/log.sh` — `RESTRUCTURE-LOG.md` writer (structured `[TIMESTAMP] [PHASE] message`, via `mutate_write --append`, dry-run safe)
- `lib/snapshot.sh` — full timestamped backup under `.conjure-adopt-backups/` via raw `cp` (precedes all `mutate_*`)
- `lib/inventory.sh` — read-only markdown scanner + 6-bucket classifier + `adopt-manifest.json` emitter
- `lib/caps.sh` — cap constants (`CLAUDE_MD_CAP=100`, `SKILL_MD_CAP=200`, `AGENT_MD_CAP=80`) + the `mutate_archive` never-delete primitive
- Finalized `adopt-manifest.json` schema (the CLI↔skill contract)

**Not this phase:** `scripts/adopt.sh` pipeline, `cmd_adopt`, rollback, signal
traps, the restructure skill, integration tests (Phases 22–24). This phase
builds the primitives those consume.

</domain>

<decisions>
## Implementation Decisions

### Classification taxonomy
- **D-01:** The manifest commits to the **6 deterministic buckets** from INV-01 as its stable contract: `core` / `skill` / `agent` / `planning-doc` / `reference-doc` / `unknown`. The richer 11-tag scheme in `ARCHITECTURE.md` (candidate-skill, candidate-agent, stale-candidate, harness-hook, reference-linked) is **rejected as the CLI contract**.
- **D-02:** `candidate-skill`, `candidate-agent`, and `stale-candidate` are **LLM judgment** — they belong to the restructure skill (Phase 23), not the deterministic CLI inventory. The CLI buckets; the skill proposes "this `unknown` looks like a skill / is stale." This preserves the split-responsibility invariant.
- **D-03:** Classification is **path-based and conservative**. Bucket primarily by location. A markdown file with skill-shaped frontmatter sitting OUTSIDE `.claude/skills/` → `unknown` (let the skill judge), never auto-promoted to `skill`. Frontmatter only confirms files already in harness directories. No false reclassification.
- **D-04:** Inventory is **markdown-only** (`*.md`). Hooks (`.mjs`) are not markdown and are therefore out of the inventory's scope — the `harness-hook` tag from research is irrelevant here.

### Inventory richness
- **D-05:** **Skip `git_age_days`** — no per-file `git log`. Rationale: (1) staleness is skill judgment per D-02; (2) ~500 git-log forks is the primary threat to the CR-7 `<30s` perf gate. The skill has Bash and can `git log` on-demand for the handful of files it reviews.
- **D-06:** **Link data = CLAUDE.md outbound links only.** One `grep` pass over CLAUDE.md extracts `](path)` links; a file linked from CLAUDE.md → `reference-doc` bucket + `linked_from: ["CLAUDE.md"]`. No per-file `links_to`, no bidirectional reverse-index across the corpus.
- **D-07:** `reference-doc` bucket is decided by **path (docs/, README.md, *.adr.md, CHANGELOG) OR CLAUDE.md-link** (D-06). A CLAUDE.md-linked doc living elsewhere is captured rather than falling to `unknown`.

### Cap & overflow semantics
- **D-08:** **>500 files → scan up to 500, flag, message.** Count total found (cheap `find | wc`), process up to 500, set `summary.scan_capped: true` + `summary.total_found`, print "`<N>` found, scanned 500 — rerun with `--full-inventory`". Do **not** enumerate the unscanned files in `files[]` (defeats the cap's purpose of bounding work + manifest size). Not a hard-stop; not scan-all.
- **D-09:** **Resolve the `cap_exceeded` name collision.** Per-file boolean `size_cap_exceeded` (`line_count > 100/200/80`) feeds `size_cap_violations[]`. The 500-file scan limit uses separate top-level `summary.scan_capped` + `summary.total_found`. Two distinct names — no ambiguity for the skill.
- **D-10:** **Harness-first budget when capped.** Always include CLAUDE.md + `.claude/**` + `.planning/**` (few, restructure-critical), then fill the remaining budget with other docs in deterministic order. The files the skill must see are never cut by the 500 cap.

### Archive primitive (`mutate_archive`)
- **D-11:** `mutate_archive` lives in **`lib/mutate.sh`** alongside `mutate_cp/write/rm`. Honors `DRY_RUN`, increments the shared `CONJURE_DRY_MUTATION_COUNT`. Upholds the locked "all writes funnel through `lib/mutate.sh`" invariant. `lib/caps.sh` sources `mutate.sh` and calls it.
- **D-12:** **Path-preserving mirror** layout: `docs/old/notes.md` → `.conjure-archive-<ts>/docs/old/notes.md`. Manual restore is obvious; two files named `CLAUDE.md` from different dirs cannot collide. One UTC-timestamped archive dir per run (`date -u +%Y%m%dT%H%M%SZ`).
- **D-13:** **Move-safety contract: copy → verify sha256 → rm + ledger.** `cp -a` to archive, verify dest sha256 == src sha256, only then `rm` the original; append `src→dest + sha256 + ts` to an archive ledger. Never unlink unverified content. This is the concrete SAFE-03 never-delete guarantee.

### Claude's Discretion
- `lib/log.sh` `RESTRUCTURE-LOG.md` exact location/header format, snapshot `cp -a` vs `cp -Rp` fallback selection, symlink/binary/vendored skip-detection mechanics (`.git`, `node_modules`, `.conjure-adopt-backups` exclusion), and the manifest dry-run `/tmp` write path were left to planning/implementation (standard patterns, per research). Follow STACK.md primitives and M-2/M-4 guidance.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap (this phase)
- `.planning/REQUIREMENTS.md` — INV-01..04, SAFE-03, ADOPT-03 (the requirements this phase satisfies)
- `.planning/ROADMAP.md` §"Phase 21: Foundation Libs + Inventory" — goal + 5 success criteria

### Research (v0.6.0 — read before planning)
- `.planning/research/SUMMARY.md` — synthesis; build order, CR-1..7 pitfalls, Phase 1 scope, Open Questions
- `.planning/research/ARCHITECTURE.md` §2 (inventory functions + classification logic) and §3 (manifest JSON schema) — the proposed schema sample; **note D-01/D-02 override its 11-tag scheme down to 6 deterministic buckets**
- `.planning/research/STACK.md` — POSIX primitives (`find -print0 | xargs -0 wc -l`, `cp -a`/`cp -Rp`, `git status --porcelain=v1`, `wc -l <`, `jq -cn --slurpfile`); zero-new-deps envelope
- `.planning/research/PITFALLS.md` — M-2 (symlink/generated filters), M-4 (UTC timestamps, quote-safe paths, `cp -a` vs `cp -r`), CR-4 (archive ≠ rollback), CR-7 (scaling/perf gate)

### Existing code to extend / mirror
- `lib/mutate.sh` — the chokepoint pattern `mutate_archive` must follow (DRY_RUN guard, counter, printf writes); unchanged otherwise
- `lib/merge.sh` — sibling lib style/structure reference
- `scripts/audit-setup.sh` — current home of the hardcoded line caps being extracted into `lib/caps.sh` (call-site change only)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/mutate.sh`: `mutate_mkdir/cp/write/rm` + `mutate_summary` + `CONJURE_DRY_MUTATION_COUNT`. `mutate_archive` is a new sibling here; `lib/log.sh` writes via `mutate_write --append`.
- `scripts/audit-setup.sh`: holds the cap constants (100/200/80) today — `lib/caps.sh` extracts them to prevent drift; audit-setup.sh sources caps.sh instead of redefining.
- `scripts/init-project.sh`, `scripts/audit-setup.sh`: called as subprocesses by the later `adopt.sh` (Phase 22) — not modified this phase.

### Established Patterns
- All filesystem mutations route through `lib/mutate.sh` (locked v0.3.0 decision) — `mutate_archive` must comply (D-11).
- POSIX bash 3.2+: no associative arrays, no `mapfile`, no `local -n`. Newline-delimited internal state (see inventory `CONJURE_INVENTORY_ITEMS` convention).
- `DRY_RUN` honored by every `mutate_*`; snapshot is the deliberate exception (raw `cp`, unconditional in live mode — must NOT route through `mutate_cp`).
- Split responsibility (v0.6.0): CLI = deterministic filesystem + bucketing; skill = judgment (candidate/stale).

### Integration Points
- `adopt-manifest.json` is the CLI→skill contract finalized here; its schema (D-01/D-06/D-09) is consumed by `scripts/adopt.sh` (writer, Phase 22) and the restructure skill (reader, Phase 23). Summary-first structure enables selective `jq` injection rather than loading the full `files[]`.
- `lib/caps.sh` is sourced by both `audit-setup.sh` and the future `adopt.sh` — single source of truth for caps.

</code_context>

<specifics>
## Specific Ideas

- Manifest schema sample to anchor against: `ARCHITECTURE.md` §3 — but the `classification` enum collapses to the 6 buckets (D-01), `git_age_days` is dropped (D-05), `cap_exceeded` is renamed `size_cap_exceeded` (D-09), and `summary.scan_capped` + `summary.total_found` are added (D-08).
- Top-level manifest keys required by ROADMAP criterion 4: `schema_version`, `summary.*`, `files[]`, `size_cap_violations[]`, `harness_missing_layers`, `restructure_steps[]` (empty at inventory time).

</specifics>

<deferred>
## Deferred Ideas

- `--quick` mode that skips `wc -l` on large files for faster network-storage scans — already tracked as **ADOPT-08 (v2)**; relevant if the CR-7 perf probe shows the 500-file scan approaching the 30s gate on CI.
- `--json` inventory/report output for CI — already tracked as **ADOPT-07 (v2)**.
- Full bidirectional link-graph (`links_to` per file + corpus-wide reverse index) for orphan detection — deferred; D-06 keeps it to CLAUDE.md outbound only for now.

None of these expanded Phase 21 scope — discussion stayed within the phase boundary.

</deferred>

---

*Phase: 21-foundation-libs-inventory*
*Context gathered: 2026-05-28*
