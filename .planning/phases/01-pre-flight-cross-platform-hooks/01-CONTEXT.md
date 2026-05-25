# Phase 1: Pre-flight & Cross-Platform Hooks - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix two live bugs and extract reusable preflight logic:
1. `templates/settings.json.tmpl` hardwires `bash .claude/hooks/*.sh` — dead on native Windows. Replace with `node .claude/hooks/*.mjs` wiring everywhere.
2. `cmd_preflight()` in `cli/conjure` is inline, always emits `brew install` regardless of OS, and never blocks. Extract to `scripts/preflight.sh` with OS-detected fix-its and a required/optional dep split.

Deliverables: `scripts/preflight.sh` (standalone, callable by CLI + tests), updated `templates/settings.json.tmpl` (node-everywhere hook wiring), `conjure preflight` user-facing subcommand.

</domain>

<decisions>
## Implementation Decisions

### Hook Wiring Strategy
- **D-01:** Always emit `node .claude/hooks/*.mjs` for all hooks on all platforms — no OS branching in init. Single `settings.json` template, no conditional paths.
- **D-02:** Use relative paths: `node .claude/hooks/foo.mjs` (matches Claude Code's project-root execution model, mirrors existing bash pattern).
- **D-03:** `node` is a **required** dep — `conjure init` blocks with a non-zero exit if node is missing. Hooks cannot fire without it.

### Required vs Optional Deps
- **D-04:** **Required (block init):** `node`, `git`
- **D-05:** **Optional (warn, continue):** `jq`, `rg`, `shellcheck`
- **D-06:** `shellcheck` is checked and warned about (audit degrades gracefully without it), not silently ignored.

### Preflight Subcommand
- **D-07:** `conjure preflight` is a **user-facing subcommand** — exposed in CLI dispatch, users and CI scripts can invoke it standalone.
- **D-08:** `scripts/preflight.sh` is called by: `conjure init`, `conjure audit`, `conjure preflight` subcommand, and `tests/run.sh`. No inline duplication.
- **D-09:** `conjure init` exits non-zero if preflight finds a required dep missing; `conjure audit` likewise blocks.

### Install Fix-it Format
- **D-10:** One copy-pasteable line per missing dep, per detected package manager. Example:
  ```
  ✗ node missing (required)
    macOS:   brew install node
    Linux:   apt install nodejs
    Windows: winget install OpenJS.NodeJS   (or: npm is already bundled with node)
  ```
- **D-11:** OS detection via `uname -s` (Darwin → macOS, Linux → Linux) + `$OSTYPE` check for msys/cygwin (Git Bash on Windows) + `uname -r` grep for "Microsoft" (WSL). Emit only the relevant package manager's line for the detected OS.
- **D-12:** Never auto-install. Report and exit (required) or report and continue (optional).

### Claude's Discretion
- Exact dep version requirements (minimum node version, minimum git version) — check what Claude Code itself requires and match.
- Whether `graphify` and `ast-grep` are still listed as optional power tools in preflight output (low priority).
- Output formatting details (emoji vs plain ASCII prefix for required/optional).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Safety & Cross-Platform — SAFE-03, SAFE-04 (the two requirements this phase addresses)
- `.planning/ROADMAP.md` §Phase 1 — Goal, success criteria, and phase boundary

### Existing Code to Modify
- `cli/conjure:169` — `cmd_preflight()` function (extract to `scripts/preflight.sh`, keep dispatch stub)
- `cli/conjure:67` — `cmd_preflight || return 1` call in `cmd_init` (update to call `scripts/preflight.sh`)
- `templates/settings.json.tmpl` — hook `command` strings (change `bash .claude/hooks/*.sh` → `node .claude/hooks/*.mjs`)

### Existing Assets to Wire
- `templates/hooks-nodejs/` — `.mjs` versions of all 5 hooks already exist and are not yet wired. Phase 1 wires them, not rewrites them.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `templates/hooks-nodejs/*.mjs` — 5 hooks (post-edit-format, pre-bash-block-destructive, pre-commit-quality-gate, session-start-context, stop-compound-engineering) ready to wire.
- `scripts/install-mcp-stack.sh`, `scripts/audit-setup.sh` — existing `command -v` patterns to reference for dep-check style consistency.

### Established Patterns
- All hooks use `exit 2` to block (never `exit 1`) — `scripts/preflight.sh` must follow same convention if it ever blocks a hook context.
- `cmd_init` already calls `cmd_preflight || return 1` at line 67 — the calling pattern is in place; just the implementation moves out.
- `templates/hooks/` (bash) and `templates/hooks-nodejs/` (node) are parallel sets. After Phase 1, `settings.json.tmpl` wires node; bash templates stay as reference but aren't the generated output.

### Integration Points
- `scripts/preflight.sh` must be invokable standalone (by `tests/run.sh`) with no dependency on CLI state — pure POSIX bash, no sourced variables from the CLI.
- `conjure preflight` dispatch slot: add to the `case` block in `cli/conjure` (line ~200).
- `lib/` directory doesn't exist yet — Phase 2 creates `lib/mutate.sh`; Phase 1 uses `scripts/` only.

</code_context>

<specifics>
## Specific Ideas

- The existing `cmd_preflight` wires as `cmd_preflight || return 1` — the extracted `scripts/preflight.sh` should exit non-zero on required-dep failure so this calling pattern continues to work unchanged.
- Fix-it output should be machine-readable enough that `tests/run.sh` can assert specific dep names appear in output (golden-file comparison in Phase 4 will test this).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Pre-flight & Cross-Platform Hooks*
*Context gathered: 2026-05-24*
