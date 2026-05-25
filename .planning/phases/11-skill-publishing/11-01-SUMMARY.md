# Plan 11-01 Summary: scripts/publish-skill.sh

**Status:** Complete
**Wave:** 1
**Date:** 2026-05-25

## Artifact

`scripts/publish-skill.sh` — new worker script, 142 lines, executable.

## What was built

Four sequential validation gates:
1. **Prerequisites** (exit 2): git installed; `.claude/skills/<name>/SKILL.md` exists
2. **SHA-pinning** (exit 1 each, per D-07/D-08): skill directory clean (`git status --porcelain`); conjure HEAD tagged (`git describe --exact-match`)
3. **Frontmatter + size** (exit 1): name present + matches `^[a-z][a-z0-9-]{1,40}$` + matches directory; description present + 30–400 chars; file ≤ 200 lines
4. **Egress scan** (exit 1): body-only grep (awk `n>=2` extraction) for network patterns (`curl|wget|\bnc\b|fetch|http://|https://`) and sensitive env refs (`$HOME|$USER|$SECRET|$API_KEY|$TOKEN|$PASSWORD`)

PR instruction printing: `gh` detection branch prints `gh pr create` command string (not executed); no-gh branch prints manual URL + checklist. `--to <org/repo>` validated and substituted in printed command. DRY_RUN=1 handled via `mutate_summary`.

## Acceptance criteria met

- Executable, shellcheck clean (CI flags: `-S error -e SC2164,SC2044,SC2034,SC2155`)
- All grep acceptance checks pass
- No-args invocation exits 1 with usage
- Existing test suite: PASS: 228, FAIL: 0

## Key design choices

- Used `git -C "$TARGET"` for skill dirty check; `git -C "$CONJURE_HOME"` for tag check (two-context requirement, Pitfall 3)
- `\bnc\b` word-boundary for netcat pattern (Pitfall 1)
- Egress scans body only via `awk n>=2` (Pitfall 7)
- `--to` target validated against `^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$` before use
