# Phase 14: Docker + Windows CI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-26
**Phase:** 14-Docker + Windows CI
**Areas discussed:** Base image, Docker CI trigger, Volume UX + README

---

## Base Image

| Option | Description | Selected |
|--------|-------------|----------|
| debian:bookworm-slim | ~75 MB base. bash, apt-get, glibc, Node.js LTS installs cleanly. Matches ubuntu-latest CI. | ✓ |
| alpine:3.x | ~7 MB base, musl libc. shellcheck arm64 risk. | |
| ubuntu:24.04 | Full Ubuntu, likely exceeds ≤200 MB gate. | |

**User's choice:** debian:bookworm-slim

| Option | Description | Selected |
|--------|-------------|----------|
| jq + shellcheck + Node.js LTS | Matches CI env exactly. conjure audit and lint both work inside container. | ✓ |
| jq + Node.js only | Smaller image, shellcheck skipped inside container. | |
| You decide | Closest to CI without exceeding 200 MB. | |

**User's choice:** jq + shellcheck + Node.js LTS

---

## Docker CI Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Every push to main + PRs | Build + smoke test on every push (~5 min). Continuous validation. | |
| Only on version tags | Docker build fires with release.yml (Phase 15). No CI job in Phase 14. | |
| Separate workflow, manual trigger | docker.yml with workflow_dispatch. Low CI cost. | ✓ |

**User's choice:** Separate workflow file, manual trigger only

| Option | Description | Selected |
|--------|-------------|----------|
| Build + smoke test only | conjure version + conjure audit against fixture. ~3 min. | ✓ |
| Build + full test suite inside container | tests/run.sh inside container. ~8 min. | |
| Build + multi-arch build check | --platform linux/amd64,linux/arm64, no push. | |

**User's choice:** Build + smoke test only

---

## Volume UX + README

| Option | Description | Selected |
|--------|-------------|----------|
| --user $(id -u):$(id -g) flag | Standard Linux/macOS pattern. Files owned by calling user. | ✓ |
| Container always UID 1000, users chown after | Simpler Dockerfile, requires chown step doc. | |
| DOCKER_UID env var + gosu entrypoint | Transparent to user, complex entrypoint. | |

**User's choice:** --user $(id -u):$(id -g) flag

| Option | Description | Selected |
|--------|-------------|----------|
| New ## Docker section in README, after Homebrew | Documents bash/PowerShell/cmd volume forms. DOCK-05 compliant. | ✓ |
| Separate DOCKER.md, linked from README | Keep README lean. | |
| You decide | Fit README's current structure. | |

**User's choice:** New ## Docker section in README, after Homebrew

---

## Claude's Discretion

- Multi-arch build strategy (docker buildx setup in CI)
- Exact WORKDIR and entrypoint in Dockerfile
- Image size assertion in smoke test

## Deferred Ideas

- Docker image publishing to ghcr.io — Phase 15 (release gate)
- release.yml wiring for Docker multi-arch build + push — Phase 15
- Action SHA pinning for docker.yml — Phase 15
