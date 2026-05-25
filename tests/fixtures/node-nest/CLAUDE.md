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


<!-- profile:node-nest -->
## Stack profile: Node + NestJS + pnpm

- Modules organized by feature (`<feature>/<feature>.module.ts`).
- WHEN adding a provider, register in module's `providers` array AND export if used elsewhere.
- WHEN writing DTOs, use `class-validator` decorators; enable `ValidationPipe` globally.
- NEVER inject providers via `new` — always constructor DI.
- WHEN writing E2E tests, use `@nestjs/testing` `Test.createTestingModule`.

### Build/test/run
| Goal | Command |
| --- | --- |
| Install | `pnpm install --frozen-lockfile` |
| Dev | `pnpm start:dev` |
| Build | `pnpm build` |
| Tests | `pnpm test` |
| E2E | `pnpm test:e2e` |
| Lint | `pnpm lint` |
