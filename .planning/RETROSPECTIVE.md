# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

---

## Milestone: v0.4.0 — Distribution + Ecosystem

**Shipped:** 2026-05-26
**Phases:** 9 | **Plans:** 23 | **Commits:** 136

### What Was Built

- Nyquist VALIDATION.md backfill for 6 completed phases — standalone verify blocks, no source-code reading required
- Real 3-way merge (`conjure update --apply`) via `git merge-file --diff3` — conflict sidecars, base snapshot at init
- `conjure publish` + `conjure publish-skill` — Marketplace manifest management + egress-scanned PR flow
- Org overlay system — `conjure init --overlay`, `conjure refresh-overlay`, audit drift detection, credential-safe
- Homebrew formula + `mislav/bump-homebrew-formula-action@v3` wired in release pipeline
- Multi-arch Docker image (linux/amd64 + linux/arm64, debian:bookworm-slim, non-root, ≤200 MB)
- windows-test CI job (`windows-latest`, shell: bash)
- 4-job release.yml: ci-gate → release → docker + homebrew (independent parallel)

### What Worked

- **Phase 15.1 as tech debt cleanup** — inserting a post-phase hotfix to clear audit-identified debt before milestone close is clean; surfaced immediately, fixed immediately
- **Audit-first before completion** — v0.4.0-MILESTONE-AUDIT.md caught the Docker+Homebrew coupling before the milestone was marked done
- **Integration checker subagent** — spawning a dedicated integration checker found the ci-gate empty-check edge case that inline review had missed
- **`lib/mutate.sh` chokepoint discipline** — every write going through mutate made dry-run testing trivial and kept 261 tests passing through 9 phases

### What Was Inefficient

- **Phase SUMMARY.md frontmatter not standardized** — `gsd-sdk summary-extract` returned `null`/`"One-liner:"` for most plans because early phases don't use consistent frontmatter; required manual override in MILESTONES.md
- **VALIDATION.md Nyquist frontmatter inconsistency** — phases 09+ have `nyquist_compliant: false` frontmatter but Phase 09 has none; Nyquist classification required manual inspection
- **ci-gate logic warnings not caught during Phase 15 planning** — the empty-check bypass and filter name mismatch should have been caught in the discuss/plan phase, not during the post-close integration check

### Patterns Established

- Decimal phase numbering (15.1) for urgent hotfixes after milestone phases are complete — clear insertion semantics without renumbering
- 4-job release.yml pattern: gate job → core job → parallel distribution jobs (each fails independently)
- HOMEBREW_TAP_GITHUB_TOKEN preflight with graceful skip — missing secret warns, doesn't fail
- Post-milestone integration checker subagent with explicit requirement ID mapping

### Key Lessons

1. **Audit before close, not after** — the milestone audit caught real issues; run it while there's still time to fix without disrupting close ceremony
2. **`human_needed` is not a gap** — live-environment tests (brew install, docker run, GitHub tag push) are expected pre-release checklist items, not failures
3. **Phase 15.1 pattern is worth institutionalizing** — "audit finds debt → insert N.1 phase → fix → mark complete → close" is a clean loop that keeps milestone scope honest
4. **Frontmatter discipline matters for tooling** — inconsistent SUMMARY.md frontmatter breaks `gsd-sdk summary-extract`; standardize early

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.3.0 | 7 | 22 | First GSD milestone; established plan→execute→verify loop |
| v0.4.0 | 9 | 23 | Added decimal phases; integration checker subagent; audit-before-close discipline |

### Cumulative Quality

| Milestone | Test Assertions | Status |
|-----------|----------------|--------|
| v0.3.0 | 203 | All green |
| v0.4.0 | 261+ | All green |
