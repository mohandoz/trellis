# Phase 21: Foundation Libs + Inventory - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 21-foundation-libs-inventory
**Areas discussed:** Classification taxonomy, Inventory richness, Cap & overflow semantics, Archive primitive design

---

## Classification taxonomy

### Taxonomy contract

| Option | Description | Selected |
|--------|-------------|----------|
| 6 deterministic buckets | core/skill/agent/planning-doc/reference-doc/unknown = INV-01; candidate/stale = skill judgment | ✓ |
| Full 11-tag scheme in CLI | ARCHITECTURE.md scheme with candidate-skill/candidate-agent/stale-candidate/harness-hook; CLI makes judgment calls | |
| 6 buckets + candidate pre-flags | Manifest commits to 6 buckets + optional 'hints' field; skill still decides | |

**User's choice:** 6 deterministic buckets

### Classification basis

| Option | Description | Selected |
|--------|-------------|----------|
| Path-based, conservative | Bucket by location; off-location skill-frontmatter file → unknown, let skill judge | ✓ |
| Frontmatter-aware | SKILL-shaped file anywhere → skill bucket regardless of path | |

**User's choice:** Path-based, conservative
**Notes:** Together these keep the CLI deterministic and the skill responsible for judgment (candidate/stale). Markdown-only inventory, so hooks (.mjs) are out of scope.

---

## Inventory richness

### Git age

| Option | Description | Selected |
|--------|-------------|----------|
| Skip git age | No per-file git log; staleness is skill judgment; protects <30s perf gate (500 forks) | ✓ |
| Include git_age_days | git log --since per file at inventory time | |

**User's choice:** Skip git age

### Links

| Option | Description | Selected |
|--------|-------------|----------|
| CLAUDE.md outbound links only | One grep pass; linked file → reference-doc + linked_from:[CLAUDE.md] | ✓ |
| Full bidirectional graph | links_to per file + corpus-wide reverse index | |
| No links — path-only reference-doc | reference-doc by location only | |

**User's choice:** CLAUDE.md outbound links only

---

## Cap & overflow semantics

### Overflow at >500 files

| Option | Description | Selected |
|--------|-------------|----------|
| Scan 500, flag + message | Count total, process 500, summary.scan_capped + total_found, message to rerun --full-inventory; don't enumerate rest | ✓ |
| Hard-stop exit 2 | Refuse over cap, force --full-inventory | |
| Scan all, warn only | Ignore cap, scan everything, warn | |

**User's choice:** Scan 500, flag + message

### Naming collision

| Option | Description | Selected |
|--------|-------------|----------|
| size_cap_exceeded + scan_capped | Per-file size_cap_exceeded → size_cap_violations[]; summary.scan_capped + total_found for the 500 limit | ✓ |
| Keep cap_exceeded = size | cap_exceeded stays line-size; add summary.scan_truncated | |

**User's choice:** size_cap_exceeded + scan_capped

### Capped budget priority

| Option | Description | Selected |
|--------|-------------|----------|
| Harness-first, then fill | Always include CLAUDE.md + .claude/** + .planning/**, then fill remaining budget | ✓ |
| Plain find order | First 500 in filesystem walk order | |

**User's choice:** Harness-first, then fill

---

## Archive primitive design

### Location

| Option | Description | Selected |
|--------|-------------|----------|
| lib/mutate.sh chokepoint | mutate_archive alongside mutate_cp/write/rm; honors DRY_RUN + shared counter | ✓ |
| New lib/archive.sh | Dedicated module; second mutation path outside chokepoint | |

**User's choice:** lib/mutate.sh chokepoint

### Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Path-preserving mirror | .conjure-archive-<ts>/ mirrors original tree; no name collisions; obvious restore | ✓ |
| Flat dir | All files dumped flat; needs disambiguation suffixes | |

**User's choice:** Path-preserving mirror

### Move-safety contract

| Option | Description | Selected |
|--------|-------------|----------|
| Copy → verify sha256 → rm + ledger | cp -a, verify dest==src sha256, then rm original; append to archive ledger; one UTC dir per run | ✓ |
| Copy then rm (no verify) | cp -a then rm; like mv, no integrity check | |
| Copy only, leave original | Backup not archive; leaves stale file in place | |

**User's choice:** Copy → verify sha256 → rm + ledger

---

## Claude's Discretion

- `lib/log.sh` `RESTRUCTURE-LOG.md` exact location/header format
- snapshot `cp -a` vs `cp -Rp` fallback selection
- symlink/binary/vendored skip-detection mechanics (`.git`, `node_modules`, `.conjure-adopt-backups`)
- manifest dry-run `/tmp` write path

All flagged as standard patterns per research (STACK.md / PITFALLS.md M-2, M-4); left to planning.

## Deferred Ideas

- `--quick` mode skipping `wc -l` on large files — tracked as ADOPT-08 (v2)
- `--json` inventory/report output for CI — tracked as ADOPT-07 (v2)
- Full bidirectional link-graph / orphan detection — deferred; D-06 keeps CLAUDE.md outbound links only
