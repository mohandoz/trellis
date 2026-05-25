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


<!-- profile:polyglot -->
## Stack profile: Polyglot (multi-language)

- Task discovery via `make help` or `just --list` (one source of truth across languages).
- WHEN editing in a language subtree, look for nested CLAUDE.md with that language's rules.
- WHEN adding a new language, add a profile overlay or nested CLAUDE.md before writing code.
- NEVER assume one stack's conventions apply to another — read the local CLAUDE.md.
