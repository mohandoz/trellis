# Phase 14: Docker + Windows CI - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Conjure runnable as a Docker container (multi-arch, non-root, ≤200 MB)
and ensure all existing CI tests pass on `windows-latest`.

Delivers:
- `Dockerfile` — multi-arch (`linux/amd64` + `linux/arm64`), non-root (`USER conjure`, UID 1000), debian:bookworm-slim base, deps: jq + shellcheck + Node.js LTS
- `.github/workflows/docker.yml` — manual `workflow_dispatch` workflow that builds the image and runs a smoke test (`conjure version` + `conjure audit`)
- `windows-latest` matrix entry in `ci.yml` — full `tests/run.sh` with `shell: bash`; `.mjs` hook wiring with `shell: pwsh`
- README `## Docker` section — bash/PowerShell/cmd volume mount forms with `--user` flag guidance
- DOCK-05 docs: `$(pwd)`, `${PWD}`, `%CD%` volume-mount forms documented

Does NOT publish the Docker image to ghcr.io (that's Phase 15 release gate), nor wire Docker into `release.yml` (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Base Image (DOCK-04)
- **D-01:** Base image is `debian:bookworm-slim`. Rationale: has bash, apt-get for jq/shellcheck, glibc, Node.js LTS installs cleanly, matches ubuntu-latest CI env, stays well under 200 MB with deps.
- **D-02:** Runtime deps installed via apt-get: `jq`, `shellcheck`, Node.js LTS (via NodeSource). These match what ubuntu-latest CI installs — container env mirrors CI exactly.
- **D-03:** Container runs as non-root: `RUN useradd -m -u 1000 conjure` + `USER conjure`. UID 1000 matches DOCK-02 requirement.

### Docker CI Trigger
- **D-04:** Docker build/test lives in a **separate `docker.yml` workflow with `workflow_dispatch` only** (manual trigger). No automatic push or tag trigger in Phase 14 — Phase 15 handles release-time Docker publishing.
- **D-05:** `docker.yml` validates: build the image, run `docker run conjure version` smoke test, run `conjure audit` against a mounted fixture. Build + smoke test only (fast, ~3 min). Full publishing is Phase 15's responsibility.

### Volume UX + Ownership (DOCK-02, DOCK-05)
- **D-06:** Users pass `--user $(id -u):$(id -g)` to run the container as their own UID. Files written to mounted volumes are owned by the calling user. This is the documented pattern in README — no gosu/su-exec entrypoint complexity.
- **D-07:** README gets a new `## Docker` section placed after the Homebrew section. Documents all three volume-mount forms:
  - bash/zsh: `-v $(pwd):/work --user $(id -u):$(id -g)`
  - PowerShell: `-v ${PWD}:/work --user ${env:UID}:${env:GID}` (or `$(id -u):$(id -g)` in Git Bash)
  - cmd: `-v %CD%:/work` (Windows cmd users likely omit `--user` and chown after)

### Windows CI (TECH-03)
- **D-08:** Add `windows-latest` to the CI matrix in `ci.yml` (or as a second job). Full `tests/run.sh` suite runs with `shell: bash` (Git Bash on windows-latest). `.mjs` hook wiring already tested in existing `windows-hook-wiring` job — extend rather than duplicate.
- **D-09:** Windows CI scope: all 265 existing tests with `shell: bash`. Any tests that need native PowerShell behavior use `shell: pwsh` explicitly. No new Windows-specific test code added in Phase 14.

### Claude's Discretion
- Multi-arch build strategy: use `docker buildx` with `--platform linux/amd64,linux/arm64`. Exact builder setup in CI is Claude's call (standard `docker/setup-buildx-action` pattern).
- WORKDIR inside container: `/work` (matches the volume mount convention in DOCK-01).
- Entrypoint: `ENTRYPOINT ["bash", "-c"]` or a thin wrapper shell script — Claude's call as long as `conjure` is on PATH inside the container.
- Image size verification: `docker image inspect` to confirm ≤200 MB in the docker.yml smoke test.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Docker Distribution — DOCK-01 through DOCK-05 (full requirement text)
- `.planning/REQUIREMENTS.md` §Technical Infrastructure — TECH-03 (Windows CI requirement)

### Existing CI
- `.github/workflows/ci.yml` — current CI job structure; `windows-hook-wiring` job is the model for Windows extension
- `.github/workflows/release.yml` — release workflow (do NOT modify in Phase 14; Phase 15 owns it)

### Existing Code
- `cli/conjure` — entrypoint script; WORKDIR `/work` with CONJURE_HOME set by wrapper or env
- `tests/run.sh` — full test suite to run on windows-latest with `shell: bash`
- `CLAUDE.md` — POSIX bash + Node.js `.mjs` constraint; size caps; safety rules

### Phase Context
- `.planning/phases/13-homebrew-tap/13-CONTEXT.md` — CONJURE_HOME resolution decisions (D-03, D-04, D-06); install layout decisions carry forward to Docker
- `.planning/ROADMAP.md` §Phase 14 — Goal, Success Criteria, Requirements list

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/run.sh` — 265 assertions, runs with `bash tests/run.sh`; needs to pass on `windows-latest` with `shell: bash` unchanged
- `.github/workflows/ci.yml` `windows-hook-wiring` job — existing model for `shell: bash` + `shell: pwsh` pattern on windows-latest
- `cli/conjure` — already has D-03 CONJURE_HOME conditional; Docker wrapper sets CONJURE_HOME before exec (same pattern as Homebrew formula)

### Established Patterns
- All CI deps installed via apt-get on ubuntu-latest (`jq`, `shellcheck`, `claude-code`) — mirror these in Dockerfile
- `lib/mutate.sh` zero-mutation pattern — must work inside container against `-v` mounted volume
- Non-root execution: `USER conjure` at UID 1000 (DOCK-02) — files written to mounted volumes use `--user $(id -u):$(id -g)` for caller ownership

### Integration Points
- Docker `WORKDIR /work` → maps to user's `$(pwd)` via `-v $(pwd):/work`
- `CONJURE_HOME` in container: set to `/usr/local/share/conjure` (or wherever Dockerfile installs conjure) — analogous to Homebrew's `share/conjure/`
- Windows CI: existing `windows-hook-wiring` job covers hooks; Phase 14 extends to full `tests/run.sh` in a matrix or new job

</code_context>

<specifics>
## Specific Ideas

- DOCK-05 README example must document cmd (`%CD%`) for Windows users who don't use Git Bash/PowerShell, with a note that `--user` is not needed on Docker Desktop for Windows (file ownership is handled by the WSL2 backend)
- docker.yml smoke test should assert image size ≤200 MB inline with `docker image inspect --format '{{.Size}}'`

</specifics>

<deferred>
## Deferred Ideas

- Docker image publishing to `ghcr.io` with semantic version tags — Phase 15 (release gate)
- `release.yml` wiring for Docker multi-arch build + push — Phase 15
- Action SHA pinning for docker.yml actions (WR-01 from Phase 13 review) — Phase 15

</deferred>

---

*Phase: 14-Docker + Windows CI*
*Context gathered: 2026-05-26*
