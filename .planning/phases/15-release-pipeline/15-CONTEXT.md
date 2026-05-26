# Phase 15: Release Pipeline - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire all distribution targets behind a single `release.yml` GitHub Actions workflow:
CI gate → create GH release → Docker build+push to ghcr.io → Homebrew SHA bump →
marketplace version check. Every artifact is blocked behind green CI (REL-02).

Delivers:
- Extended `.github/workflows/release.yml` — two-job structure: `ci-gate` + `release`
- `ci-gate` job verifies the tagged commit's CI checks before any publishing step
- `release` job: marketplace version check → CHANGELOG extract → GH release create
  → Docker multi-arch build + push to ghcr.io → Homebrew SHA bump
- DOCK-03 satisfied: image published to `ghcr.io/mohandoz/conjure` with semver tag + `latest`
- REL-01 satisfied: all three distribution targets fire in one workflow under one gate
- REL-02 satisfied: ci-gate job blocks the release job if any required check failed

Does NOT add new tests, new commands, or change docker.yml (that workflow stays manual).
Does NOT modify ci.yml. Sole file modified: `.github/workflows/release.yml`.

</domain>

<decisions>
## Implementation Decisions

### CI Gate Mechanism (REL-02)
- **D-01:** Add a `ci-gate` job as the first job in release.yml. It runs on ubuntu-latest,
  uses `gh api` to query the tagged commit's check-runs (`/repos/:owner/:repo/commits/:sha/check-runs`),
  and fails if any check that is not itself the release workflow is in a non-success state.
  The `release` job has `needs: [ci-gate]` — nothing publishes until ci-gate passes.
- **D-02:** The check: `gh api /repos/${{ github.repository }}/commits/${{ github.sha }}/check-runs`
  filtered to non-release checks. Accept states: `success`, `skipped`, `neutral`. Fail on: `failure`,
  `timed_out`, `cancelled`, `action_required`. Exit non-zero if any required check is non-passing.
  Use `GITHUB_TOKEN` (built-in) — no extra secret needed.

### Job Structure (REL-01, REL-02)
- **D-03:** Two-job structure:
  ```
  ci-gate (runs first)
    ↓
  release (needs: [ci-gate])
    1. Verify VERSION matches tag            (exists — no change)
    2. Marketplace version check             (new: re-run ci.yml check inline)
    3. Docker setup: containerd + QEMU + buildx + login (new)
    4. Docker build + push multi-arch       (new)
    5. Extract CHANGELOG                    (exists — no change)
    6. Create GitHub release                (exists — no change)
    7. Bump Homebrew formula                (exists — no change)
  ```
  Marketplace check runs BEFORE creating the GH release (fail fast, no partial publish).
  Docker build runs BEFORE creating GH release too (fail fast).
  CHANGELOG extraction and GH release creation stay at the end (only if everything passes).

### Marketplace Version Check (REL-01c)
- **D-04:** Re-run the same 5-line version consistency check from ci.yml verbatim as a defensive
  step in release.yml. Since CI runs on branch push (not on tags), the marketplace check may
  not have run on the exact tagged commit's release.yml context. Re-running it here is cheap
  and explicit. Script: compare `jq -r '.plugins[0].version' .claude-plugin/marketplace.json`
  and `jq -r '.version' .claude-plugin/plugin.json` against `cat VERSION`.

### Docker Build + Push (DOCK-03)
- **D-05:** Use the same action versions as docker.yml (Wave 2, plan 14-02):
  - `docker/setup-docker-action@v4` with containerd snapshotter
  - `docker/setup-qemu-action@v3`
  - `docker/setup-buildx-action@v3`
  - `docker/login-action@v3` — registry: `ghcr.io`, username: `${{ github.actor }}`,
    password: `${{ secrets.GITHUB_TOKEN }}`
  - `docker/build-push-action@v6` — `push: true`, platforms: `linux/amd64,linux/arm64`,
    tags: `ghcr.io/mohandoz/conjure:${{ github.ref_name }},ghcr.io/mohandoz/conjure:latest`
- **D-06:** No `docker/metadata-action`. Tags are hardcoded from `github.ref_name`
  (which equals the tag, e.g., `v0.4.0`). Simple and consistent with existing release.yml style.
- **D-07:** Image size is NOT re-asserted in release.yml — that's docker.yml's job (manual
  workflow). Release trusts that the Dockerfile is correct if it built successfully.

### Permissions (DOCK-03, REL-01)
- **D-08:** The `release` job needs `packages: write` permission added (for ghcr.io push)
  in addition to the existing `contents: write`. Set both in the job-level `permissions:` block.
  The `ci-gate` job only reads check-runs (GITHUB_TOKEN read scope is default).

### Claude's Discretion
- The ci-gate check logic (gh api call + jq filter) is Claude's implementation choice as long
  as it: (a) reads from the tagged commit SHA, (b) fails on any non-success check that is not
  the release workflow itself, (c) uses GITHUB_TOKEN.
- Step naming in release.yml is Claude's choice — match existing style (title case, no emojis).
- Whether to use `continue-on-error: false` (default) is Claude's call — standard default is correct.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Release Pipeline Wiring — REL-01, REL-02 (full requirement text)
- `.planning/REQUIREMENTS.md` §Docker Image — DOCK-03 (image publishing requirement)

### Existing Workflows
- `.github/workflows/release.yml` — CURRENT state; extend this file (do NOT replace wholesale)
- `.github/workflows/ci.yml` — marketplace version check is at lines ~42-52; Docker action
  versions used in docker.yml must match those used in release.yml
- `.github/workflows/docker.yml` — action versions reference (containerd, QEMU, buildx, build-push)

### Phase Context
- `.planning/phases/14-docker-windows-ci/14-CONTEXT.md` — Docker decisions (D-01 through D-09);
  action versions; containerd snapshotter rationale
- `.planning/phases/13-homebrew-tap/13-CONTEXT.md` — Homebrew bump action decisions (carry forward)

### Project
- `.planning/ROADMAP.md` §Phase 15 — Goal, Success Criteria, Requirements list
- `CLAUDE.md` — POSIX bash + Node.js constraint; safety rules (no curl|sh foot-guns)

</canonical_refs>

<code_context>
## Existing Code Insights

### release.yml Current State
- One job: `release`, `ubuntu-latest`, `permissions: contents: write`
- Steps that EXIST and must NOT change: Verify VERSION, Extract CHANGELOG, Create release (softprops/action-gh-release@v2), Bump Homebrew (mislav/bump-homebrew-formula-action@v3)
- HOMEBREW_TAP_GITHUB_TOKEN secret already referenced — confirmed in place

### ci.yml Marketplace Check (copy verbatim to release.yml)
```bash
ver=$(cat VERSION)
mkt_ver=$(jq -r '.plugins[0].version // empty' .claude-plugin/marketplace.json)
plg_ver=$(jq -r '.version // empty' .claude-plugin/plugin.json)
rc=0
[ "$mkt_ver" = "$ver" ] || { echo "FAIL: marketplace.json version ($mkt_ver) != VERSION ($ver)"; rc=1; }
[ "$plg_ver"  = "$ver" ] || { echo "FAIL: plugin.json version ($plg_ver) != VERSION ($ver)"; rc=1; }
[ "$rc" -eq 0 ] && echo "OK: all version fields match $ver"
exit "$rc"
```

### Docker Action Versions (from docker.yml — must match)
- docker/setup-docker-action@v4
- docker/setup-qemu-action@v3
- docker/setup-buildx-action@v3
- docker/build-push-action@v6
- actions/checkout@v4
- docker/login-action@v3 (not in docker.yml — standard version for this action family)

### ghcr.io Registry Pattern
- Registry: `ghcr.io`
- Image: `ghcr.io/mohandoz/conjure`
- Tags: `ghcr.io/mohandoz/conjure:${{ github.ref_name }}` + `ghcr.io/mohandoz/conjure:latest`
- Auth: `GITHUB_TOKEN` (built-in, no additional secret required)

</code_context>
