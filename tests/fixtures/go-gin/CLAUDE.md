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


<!-- profile:go-gin -->
## Stack profile: Go + Gin + go modules

- Go version pinned in `go.mod`. `toolchain` directive used.
- WHEN handling errors, check explicitly — NEVER `_ = err`.
- WHEN spawning goroutines, ALWAYS pass cancellation context.
- NEVER use `panic` for control flow; reserve for unrecoverable startup errors.
- WHEN writing handlers, bind+validate request via `c.ShouldBindJSON`.
- WHEN testing, use table-driven tests + `t.Run` subtests.

### Build/test/run
| Goal | Command |
| --- | --- |
| Build | `go build ./...` |
| Run | `go run ./cmd/<bin>` |
| Tests | `go test ./...` |
| Race | `go test -race ./...` |
| Format | `gofmt -w .` |
| Lint | `golangci-lint run` |
| Vuln scan | `govulncheck ./...` |
