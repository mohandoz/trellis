# Plan 11-02 Summary: cli/conjure + tests/run.sh

**Status:** Complete
**Wave:** 2
**Date:** 2026-05-25

## Artifacts

- `cli/conjure` — added `cmd_publish_skill()` function, `publish-skill)` dispatch case, usage line
- `tests/run.sh` — added SKILL-01 through SKILL-04 regression block (13 test cases)

## What was built

### cli/conjure
- `cmd_publish_skill()` at ~20 lines, matching `cmd_publish()` shape exactly
- Positional skill name + `--to <org/repo>` + `--dry-run` flag parsing
- Empty-name guard: exits 1 with usage if no skill name given
- Dispatches to `scripts/publish-skill.sh` with `CONJURE_HOME`, `DRY_RUN`, `TARGET_REPO` env vars
- `publish-skill)` case inserted in dispatch table before `version` case
- `conjure publish-skill <name> [--to <org/repo>] [--dry-run]` added to `usage()` heredoc

### tests/run.sh
- SKILL sandbox pattern mirrors MKTPL block: `mktemp -d`, real git repo, committed SKILL.md, annotated tag
- `skill_run()` helper wraps `( cd "$SKILL_DIR" && bash ... )` since script uses `$(pwd)` for skill path
- SKILL-01: dry-run, size cap, missing frontmatter name, curl egress, $SECRET egress, clean pass
- SKILL-02: gh-present (stub bin) → prints `gh pr create`; gh-absent (filtered PATH) → prints manual URL
- SKILL-03: dirty tree → exit 1 with "uncommitted"; untagged conjure HEAD → exit 1 with "tagged release"
- SKILL-04: `--to myorg/myrepo` appears in PR output

## Key fix discovered

`git describe --exact-match HEAD` ignores lightweight tags — requires annotated tags. Test sandbox uses `git tag -a "v..." -m "release"` to correctly simulate a tagged release.

## Acceptance criteria met

- `cmd_publish_skill()` present; `publish-skill)` dispatch present; usage updated (all grep checks pass)
- `shellcheck -S error` clean on both files
- `bash cli/conjure publish-skill` exits 1 with usage
- `bash tests/run.sh` exits 0 — PASS: 241, FAIL: 0
- All 13 SKILL-01 through SKILL-04 tests pass
