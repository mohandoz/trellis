# GENERATED — do not edit directly; run scripts/regen-fixtures.sh

## Project

Fixture project.

### Constraints

- POSIX bash + Node.js .mjs hooks.

## Technology Stack

See profile fragment below.

## Conventions

None.

## Architecture

Standard conjure harness layout.

## Developer Notes


<!-- profile:monorepo -->
## Stack profile: Monorepo

- WHEN adding a dependency to package X, ALWAYS check if `@repo/shared` (or equivalent) already provides it.
- WHEN running tests, scope with `--filter` (pnpm/Turbo) or per-package — NEVER run full suite for a single-package change.
- WHEN editing a package, prefer that package's nested `CLAUDE.md` for local rules. Root CLAUDE.md is for cross-cutting only.
- NEVER install packages to the root `package.json` unless they're build tooling.

Per-package conventions live in `<package>/CLAUDE.md` (loads when Claude reads files in that subtree).
