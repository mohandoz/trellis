# Milestones

## v0.4.0 Distribution + Ecosystem (Shipped: 2026-05-26)

**Phases completed:** 9 phases, 23 plans
**Timeline:** 2026-05-25 → 2026-05-26 | 136 commits | 197 files changed

**Key accomplishments:**

- Nyquist backfill: 6 VALIDATION.md files for phases 01, 02, 04, 05, 06, 07 with executable verify blocks (TECH-02a–f)
- 3-Way Merge: `conjure update --apply` uses real `git merge-file --diff3`; conflict sidecars + base snapshot at init (MERGE-01–05)
- Marketplace Publish: `conjure publish` + CI version-consistency + `claude plugin validate` in CI (MKTPL-01–04)
- Skill Publishing: `conjure publish-skill` with 4-gate validation (schema, size, egress, SHA-pin) + PR flow (SKILL-01–04)
- Org Overlay: `conjure init --overlay` + `conjure refresh-overlay` + audit drift reporting; credential-safe (OVLY-01–05)
- Homebrew Tap: formula + `mislav/bump-homebrew-formula-action@v3` wired in release pipeline (BREW-01–04)
- Docker + Windows CI: multi-arch Dockerfile (debian:bookworm-slim, non-root) + docker.yml + windows-test CI job (DOCK-01–05, TECH-03)
- Release Pipeline: 4-job release.yml — ci-gate → release → docker + homebrew (parallel, independent) (REL-01–02)

**Known deferred items at close:** 9 (see .planning/STATE.md Deferred Items)

---
