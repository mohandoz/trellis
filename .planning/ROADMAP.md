# Roadmap: Conjure

## Completed Milestones

- **v0.3.0** — "Testing + Telemetry" — 7 phases, 22 plans, 20/20 requirements satisfied, 169 commits (2026-05-24 → 2026-05-25) — [Archive](.planning/milestones/v0.3.0-ROADMAP.md)
- **v0.4.0** — "Distribution + Ecosystem" — 9 phases, 23 plans, 29/29 requirements satisfied, 136 commits (2026-05-25 → 2026-05-26) — [Archive](.planning/milestones/v0.4.0-ROADMAP.md)

## Active Milestone

(none — start next with `/gsd-new-milestone`)

## Phases

<details>
<summary>✅ v0.4.0 Distribution + Ecosystem (Phases 08-15.1) — SHIPPED 2026-05-26</summary>

- [x] **Phase 08: Nyquist Compliance Backfill** - Write VALIDATION.md for phases 01, 02, 04, 05, 06, 07 (completed 2026-05-25)
- [x] **Phase 09: 3-Way Merge** - Implement `cmd_update --apply` via `lib/merge.sh` + base snapshot (completed 2026-05-25)
- [x] **Phase 10: Marketplace Publish** - Wire and validate the Claude Code Marketplace plugin manifest (completed 2026-05-25)
- [x] **Phase 11: Skill Publishing** - Add `conjure publish-skill` command with egress scan + PR flow (completed 2026-05-25)
- [x] **Phase 12: Org Overlay** - Implement `conjure init --overlay` + `conjure refresh-overlay` system (completed 2026-05-25)
- [x] **Phase 13: Homebrew Tap** - Publish `mohandoz/homebrew-conjure` formula and auto-bump action (completed 2026-05-25)
- [x] **Phase 14: Docker + Windows CI** - Multi-arch Docker image and `windows-latest` CI matrix entry (completed 2026-05-26)
- [x] **Phase 15: Release Pipeline** - Single `release.yml` wires all distribution targets under one gate (completed 2026-05-26)
- [x] **Phase 15.1: Fix release.yml Docker+Homebrew coupling** - Decouple Docker and Homebrew into independent jobs; add HOMEBREW_TAP_GITHUB_TOKEN preflight (completed 2026-05-26)

</details>

## Backlog

### Future Milestones

- v0.5.0 — Auto-update drift detector, auto-PR bot (needs frozen schemas first)
- v0.6.0 — Workspace / cross-repo graph orchestration (single-repo correctness first)
