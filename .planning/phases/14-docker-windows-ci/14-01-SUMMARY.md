---
phase: 14
plan: 01
subsystem: docker
tags: [dockerfile, dockerignore, non-root, debian, nodejs]
dependency_graph:
  requires: []
  provides: [Dockerfile, .dockerignore]
  affects: [docker.yml, README.md]
tech_stack:
  added: [debian:bookworm-slim, NodeSource setup_22.x, Node.js 22]
  patterns: [non-root-container, homebrew-shim-mirror, single-layer-deps]
key_files:
  created:
    - Dockerfile
    - .dockerignore
  modified: []
decisions:
  - "Base image: debian:bookworm-slim (D-01)"
  - "All apt deps + NodeSource setup in one RUN layer to minimize layer size"
  - "Non-root user conjure at UID 1000 (DOCK-02, D-03)"
  - "Thin wrapper at /usr/local/bin/conjure mirrors Homebrew formula shim pattern"
  - "WORKDIR /work created as root before USER switch (pitfall-3 avoidance)"
  - ".dockerignore excludes .planning/, tests/output/, tests/tmp/, .git/, .github/, Formula/, docs-only .md files, install.sh; keeps README.md and VERSION"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-26T00:36:21Z"
  tasks_completed: 2
  files_created: 2
---

# Phase 14 Plan 01: Dockerfile + .dockerignore Summary

**One-liner:** Debian bookworm-slim image with single-layer deps (jq + shellcheck + Node.js 22 via NodeSource), non-root conjure user (UID 1000), and Homebrew-mirrored wrapper shim.

## What Was Created

### Dockerfile (`/Dockerfile`)

Layer structure (in order):

1. `FROM debian:bookworm-slim` — slim Debian 12 base
2. Single `RUN` layer: `apt-get install` (ca-certificates, curl, gnupg, jq, shellcheck) + NodeSource `setup_22.x` script + `apt-get install nodejs` + cache cleanup — all in one layer to keep net size minimal
3. `RUN useradd -m -u 1000 -s /bin/bash conjure` — non-root user (DOCK-02, D-03)
4. `ENV CONJURE_HOME=/usr/local/share/conjure`
5. Eight `COPY` directives mirroring the Homebrew formula install layout (`cli/`, `scripts/`, `profiles/`, `compliance/`, `migrations/`, `templates/`, `lib/`, `VERSION`)
6. `RUN` block: `chmod +x` the CLI, write wrapper shim at `/usr/local/bin/conjure` (mirrors Homebrew formula shim), `chmod +x` wrapper, `mkdir -p /work`
7. `USER conjure` — switch to non-root
8. `WORKDIR /work` — maps to user's `$(pwd)` via `-v $(pwd):/work`
9. `ENTRYPOINT ["conjure"]` — direct entrypoint via PATH wrapper

No `CMD` instruction (per plan spec).

### .dockerignore (`/.dockerignore`)

Excludes planning artifacts, test output, git internals, GitHub workflows, Homebrew formula, docs-only markdown files, and `install.sh`. Retains `README.md` and `VERSION` (required in image and context).

## Verification Results

```
grep -c 'debian:bookworm-slim' Dockerfile          → 1  PASS
grep -c 'useradd.*-u 1000' Dockerfile              → 1  PASS
grep -c '^USER conjure' Dockerfile                 → 1  PASS
grep -c 'CONJURE_HOME=/usr/local/share/conjure'    → 2  PASS (ENV + printf wrapper, both correct)
grep -c 'ENTRYPOINT \["conjure"\]' Dockerfile      → 1  PASS
grep -c '\.planning/' .dockerignore                → 1  PASS
grep -c '\.git/' .dockerignore                     → 1  PASS
grep -c '^CMD' Dockerfile                          → 0  PASS (no CMD)
```

## Deviations from Plan

None — plan executed exactly as written. The `CONJURE_HOME` grep returns 2 (plan spec was not explicit about count) because the value appears in both the `ENV` directive and inside the `printf` wrapper string — both are intentional and correct.

## Notes

- Pitfall 3 (WORKDIR owned by root confusing USER conjure writes) was proactively avoided by creating `/work` in the root-owned `RUN` block before `USER conjure`, then setting `WORKDIR /work` after the switch.
- The NodeSource `curl | bash -` pattern is used at Docker build time only (not in Conjure's own scripts), consistent with the CLAUDE.md constraint interpretation documented in RESEARCH.md Open Questions #2.
- Estimated uncompressed image size: ~160–175 MB (well under the 200 MB DOCK-04 cap); actual size will be confirmed by `docker.yml` smoke test in Plan 14-02.

## Self-Check: PASSED

- `/Users/mohandoz/u01/innovate/conjure/Dockerfile` — exists
- `/Users/mohandoz/u01/innovate/conjure/.dockerignore` — exists
- All grep verification checks passed (see above)
