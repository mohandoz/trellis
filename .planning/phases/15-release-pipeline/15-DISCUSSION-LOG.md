# Phase 15 Discussion Log: Release Pipeline

**Date:** 2026-05-26
**Mode:** autonomous (auto-advance)

## Gray Areas Identified

| Area | Options Considered | Decision |
|------|-------------------|----------|
| CI gate mechanism | workflow_run trigger / gh api check-runs / branch protection rules | gh api check-runs in ci-gate job (D-01, D-02) |
| Job structure | Single job (all steps) / Two jobs (ci-gate + release) | Two jobs with needs: [ci-gate] (D-03) |
| Marketplace check | Skip (CI already ran it) / Re-run defensively | Re-run verbatim from ci.yml (D-04) |
| Docker tags | semver only / semver + latest / semver + latest + major | semver (ref_name) + latest (D-05, D-06) |
| Docker metadata | docker/metadata-action / hardcoded tags | Hardcoded for simplicity (D-06) |

## Decisions at Claude's Discretion

- ci-gate implementation (gh api jq filter logic)
- Step naming convention (matched existing release.yml style)
- Step ordering within release job (fail-fast: marketplace + docker before GH release creation)

## Deferred Ideas

None — phase is narrowly scoped to wiring existing artifacts.

## Carry-Forward Decisions

- Docker action versions from Phase 14: docker/setup-docker-action@v4, setup-qemu@v3, setup-buildx@v3, build-push@v6
- HOMEBREW_TAP_GITHUB_TOKEN already in place from Phase 13
- GITHUB_TOKEN used for ghcr.io push (no additional secret needed)
