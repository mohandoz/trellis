## What changed

<one paragraph>

## Why

<motivation; reference issue if applicable: closes #N>

## Type

- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking; new skill, agent, hook, profile, migration)
- [ ] Breaking change (requires major version bump)
- [ ] Documentation
- [ ] Refactor / housekeeping

## Checklist

- [ ] `bash tests/run.sh` is green.
- [ ] CHANGELOG.md updated under `[Unreleased]`.
- [ ] If new template / migration / profile: at least one test assertion added.
- [ ] If changing CLAUDE.md template: line count still ≤100.
- [ ] If changing a skill: still ≤200 lines, description still concrete.
- [ ] If changing a hook: still <2s; exit codes correct (2 = block).
- [ ] If changing settings.json schema: schemas in `.claude-plugin/SCHEMAS/` updated.
- [ ] No `@imports` introduced anywhere.
- [ ] Cross-platform (Node.js .mjs version added if bash hook changed).
- [ ] Cited sources for any new best-practice claim.

## Screenshots / output (if user-visible)

<paste here>
