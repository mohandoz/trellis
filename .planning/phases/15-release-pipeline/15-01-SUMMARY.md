---
phase: 15
plan: "01"
subsystem: release-pipeline
tags: [release, docker, ci-gate, homebrew, marketplace]
dependency_graph:
  requires: [14-02]
  provides: [REL-01, REL-02, DOCK-03]
  affects: [.github/workflows/release.yml]
tech_stack:
  added: []
  patterns: [ci-gate job pattern, docker multi-arch push on tag]
key_files:
  created:
    - .planning/phases/15-release-pipeline/15-VALIDATION.md
    - .planning/phases/15-release-pipeline/15-01-SUMMARY.md
  modified:
    - .github/workflows/release.yml
decisions:
  - "ci-gate job uses gh api check-runs endpoint with GITHUB_TOKEN (no extra secret)"
  - "release job gains packages: write permission for ghcr.io push"
  - "Marketplace version check re-run inline in release.yml (defensive, fail-fast before publishing)"
  - "Docker steps inserted before CHANGELOG extraction — fail fast if image build fails"
metrics:
  duration: ~5 minutes
  completed: 2026-05-26
---

# Phase 15 Plan 01: Extend Release Workflow Summary

Extended `.github/workflows/release.yml` with two-job structure: `ci-gate` blocks all publishing until CI checks are green on the tagged commit, then `release` runs the full distribution sequence — marketplace version check, Docker multi-arch build+push to ghcr.io, CHANGELOG extraction, GH release creation, and Homebrew formula bump.

## What Was Done

### Task 1: Rewrote .github/workflows/release.yml

The workflow moved from a single `release` job to a two-job structure:

**ci-gate job (new):**
- Runs `gh api /repos/:owner/:repo/commits/:sha/check-runs` against the tagged commit SHA
- Filters out the Release workflow itself
- Fails if any check is in `failure`, `timed_out`, `cancelled`, or `action_required` state
- Uses `GITHUB_TOKEN` (built-in) — no additional secret required

**release job (extended):**
- `needs: [ci-gate]` — cannot run until ci-gate passes
- `permissions: contents: write, packages: write` — added `packages: write` for ghcr.io
- Added Marketplace version check step (inline from ci.yml — defensive, runs before publishing)
- Added Docker setup sequence: `setup-docker-action@v4` (containerd snapshotter) + `setup-qemu-action@v3` + `setup-buildx-action@v3` + `login-action@v3` to ghcr.io
- Added `build-push-action@v6` with `push: true`, `platforms: linux/amd64,linux/arm64`, tags: `ghcr.io/mohandoz/conjure:${{ github.ref_name }}` + `:latest`
- Existing steps unchanged: Verify VERSION matches tag, Extract CHANGELOG entry, Create release (softprops/action-gh-release@v2), Bump Homebrew formula (mislav/bump-homebrew-formula-action@v3)

**Step order in release job:**
1. actions/checkout@v4
2. Verify VERSION matches tag (unchanged)
3. Marketplace version check (new — fail fast before any publish)
4. Set up Docker daemon (new)
5. Set up QEMU (new)
6. Set up Docker Buildx (new)
7. Login to GitHub Container Registry (new)
8. Build and push Docker image (new)
9. Extract CHANGELOG entry (unchanged)
10. Create release (unchanged)
11. Bump Homebrew formula (unchanged)

### Task 2: Created 15-VALIDATION.md

Validation document covering REL-01, REL-02, DOCK-03 with grep and python3 assertions, YAML integrity check, and manual-only verification table.

## Verification Results

All 13 automated assertions passed:

```
REL-01: ci-gate job present       PASS
REL-01: Homebrew step present     PASS
REL-01: Docker push step present  PASS
REL-01: Marketplace check present PASS
REL-01: release needs ci-gate     PASS

REL-02: ci-gate job              PASS
REL-02: needs: [ci-gate]         PASS
REL-02: check-runs API           PASS
REL-02: failure check            PASS

DOCK-03: ghcr.io/mohandoz/conjure PASS
DOCK-03: latest tag               PASS
DOCK-03: push: true               PASS
DOCK-03: linux/amd64,linux/arm64  PASS

YAML integrity (full python3)     PASS
```

## Must-Haves Confirmed

| Must-Have | Status |
|-----------|--------|
| ci-gate job exists and blocks release | Confirmed — `needs: [ci-gate]` in release job |
| release gates on CI check-runs API | Confirmed — gh api query on tagged SHA |
| Docker image pushed to ghcr.io with semver + latest | Confirmed — build-push-action push: true |
| Multi-arch: linux/amd64 + linux/arm64 | Confirmed — platforms field |
| packages: write permission on release job | Confirmed |
| Marketplace version check before publish | Confirmed — step 3 of 11, before any publish action |
| Homebrew bump unchanged | Confirmed — step text identical to prior version |
| CHANGELOG extract + GH release unchanged | Confirmed — step text identical to prior version |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no hardcoded empty values or placeholder text introduced.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes beyond the planned ghcr.io push already defined in the threat model.

## Self-Check: PASSED

- `.github/workflows/release.yml` exists and YAML-valid
- `.planning/phases/15-release-pipeline/15-VALIDATION.md` exists
- Commits exist: `cabbc9c` (release.yml)
