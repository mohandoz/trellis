# Phase 7: Skill-Firing Telemetry - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship opt-in, local-only, PII-free skill-firing telemetry that appends a JSONL event
log to `.claude/telemetry/` in the target project, with zero network egress. The
telemetry powers a "retire-list" section in `conjure audit` that surfaces skills
never loaded across recent sessions. A CI test asserts no egress exists in any
shipped hook. `TELEMETRY.md` schema doc ships in the same change as the hook.

Requirements: TLMY-01, TLMY-02, TLMY-03, TLMY-04, TLMY-05.

</domain>

<decisions>
## Implementation Decisions

### Opt-In Mechanism
- **D-01:** Telemetry is activated via `CONJURE_TELEMETRY=1` env var in the target
  project's `.claude/settings.json` `env` block. Matches the `CONJURE_COST=1`
  pattern from Phase 6 — consistent, discoverable, zero new config format.
- **D-02:** Hook exits 0 silently when `CONJURE_TELEMETRY` is unset or `!= "1"`.
  `DO_NOT_TRACK=1` also suppresses all writes (checked before the env-var check).

### Hook Strategy
- **D-03:** Two hooks in `templates/hooks-nodejs/skill-telemetry.mjs`:
  - `PreToolUse` matcher `Skill` — fires when Claude invokes a skill via the
    tool interface (confirmed in CC ≥2.1.117 as HIGH-confidence).
  - `UserPromptExpansion` (no matcher needed) — fires for user-typed `/skillname`
    commands; filter to entries where `tool_name` or input indicates a skill.
  Both hooks are the same `.mjs` file (reads stdin, branches on `hook_event_name`).
- **D-04:** Hook wired in `settings.json.tmpl` with a comment block explaining it
  is opt-in. Users uncomment to enable:
  ```json
  "_comment_telemetry": "Uncomment to enable opt-in skill-firing telemetry (CONJURE_TELEMETRY=1 in env required)",
  ```
  The hook entries are present but the env var gate means they write nothing unless
  opted in — no need to comment out the hook command itself.

### JSONL Schema
- **D-05:** One JSON object per line, fields:
  ```json
  {
    "ts": "2026-05-25T03:00:00.000Z",
    "session_id": "abc123",
    "event": "skill_invoke",
    "skill": "gsd-execute-phase",
    "project_cwd": "/Users/x/myproject"
  }
  ```
  - `ts`: ISO 8601 UTC timestamp
  - `session_id`: from hook input (passed by CC)
  - `event`: `"skill_invoke"` (PreToolUse/Skill) or `"skill_typed"` (UserPromptExpansion)
  - `skill`: skill name only — no args (args may contain PII)
  - `project_cwd`: working directory as project identifier — already in env, not PII
- **D-06:** Log file path: `{target}/.claude/telemetry/skill-events.jsonl`. Directory
  created by hook on first write (no pre-creation needed). Append-only (`>>`).

### Retire-List Integration (conjure audit)
- **D-07:** `conjure audit` gains a `--retire-list` flag (separate from `--cost`).
  Also composable: `conjure audit --cost --retire-list .`. Reads JSONL from target's
  `.claude/telemetry/skill-events.jsonl`. If file absent, prints advisory and skips.
- **D-08:** Retire-list output: a count-sorted table after the PASS/WARN/FAIL summary
  (same positioning as `--cost`). Columns: `Skill | Sessions | Loads | Status`.
  Skills with 0 loads across all recorded sessions are flagged `[retire?]`.
  Skills loaded ≥1 are flagged `[active]`.
- **D-09:** Retire-list section header: `── Skill Retire-List ──`. Counts events within
  last 30 days (configurable via `CONJURE_RETIRE_DAYS`, default 30). If no events in
  range, prints `  No telemetry data in last 30 days.`
- **D-10:** `cli/conjure cmd_audit()` parses `--retire-list` flag alongside `--cost`
  and `--exact`, passes as `CONJURE_RETIRE=1` env var to `scripts/audit-setup.sh`.
  Follows same pattern as `CONJURE_COST=1`.

### No-Egress CI Test
- **D-11:** `tests/run.sh` gains a "Telemetry no-egress" section that greps ALL files
  in `templates/hooks-nodejs/` for: `curl`, `fetch`, `http`, `socket`, `XMLHttpRequest`,
  `require('https')`, `require('http')`, `import.*https`, `import.*http`, `net.Socket`.
  Test fails if any match found in the telemetry hook file specifically.

### File Layout
- **D-12:** New files:
  - `templates/hooks-nodejs/skill-telemetry.mjs` — the hook (PreToolUse + UserPromptExpansion)
  - `TELEMETRY.md` — schema doc at repo root (alongside README.md)
- **D-13:** Modified files:
  - `templates/settings.json.tmpl` — add PreToolUse Skill + UserPromptExpansion hook entries
  - `scripts/audit-setup.sh` — add retire-list section (after cost section pattern)
  - `cli/conjure` — add `--retire-list` flag parsing in `cmd_audit()`
  - `tests/run.sh` — add telemetry tests section (TLMY-01 through TLMY-05)

### Claude's Discretion
- Exact column widths in the retire-list ASCII table
- Whether session count is derived from unique `session_id` values or just presence of any event per day
- Whether `CONJURE_RETIRE_DAYS` env override is implemented in v0.3.0 or deferred (simple cutoff acceptable)
- Exact wording in `TELEMETRY.md` beyond what requirements specify

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §TLMY-01–TLMY-05 — all 5 telemetry requirements
- `.planning/ROADMAP.md` §Phase 7 — goal, success criteria, research note on hook confidence

### Prior Phase Patterns
- `scripts/audit-setup.sh` — cost section pattern (lines ~120–200); retire-list section follows same structure
- `cli/conjure` — `cmd_audit()` flag parsing pattern; `--retire-list` added alongside `--cost`/`--exact`
- `templates/settings.json.tmpl` — hook wiring pattern; telemetry entries added to PreToolUse + new UserPromptExpansion block
- `templates/hooks-nodejs/session-start-context.mjs` — existing hook pattern (stdin read, process.exit(0))
- `templates/hooks-nodejs/pre-bash-block-destructive.mjs` — PreToolUse hook with blocking pattern
- `tests/run.sh` — test section pattern; cost section (lines ~400+) is closest analog
- `lib/prices.json` — baked JSON data file pattern; no new pattern needed for JSONL

### Hook API (Verified)
- Hook event `PreToolUse` with `matcher: "Skill"` fires for tool-invoked skills in CC ≥2.1.117
- Hook event `UserPromptExpansion` fires for user-typed `/skillname` (no matcher needed)
- Stdin payload includes: `hook_event_name`, `tool_name`, `tool_input.skill` (or similar), `session_id`, `cwd`
- Exit 0 = allow; exit 2 = block (must exit 0 — telemetry never blocks)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `templates/hooks-nodejs/*.mjs`: stdin JSON read pattern — copy verbatim into skill-telemetry.mjs; the timeout guard (10s stdinTimeout) is essential
- `scripts/audit-setup.sh` cost section: `mktemp`-based accumulator, `jq` parsing, printf ASCII table — same pattern for retire-list
- `tests/lib/sandbox.sh`: `sandbox_setup` isolates test runs from real HOME — use for telemetry tests

### Established Patterns
- Env-var gate (`CONJURE_COST=1`): hook checks env var and exits 0 silently when off — telemetry gate same
- `DO_NOT_TRACK` convention: check `$DO_NOT_TRACK` before writing (standard Unix convention; exit 0 if set)
- Node `.mjs` hooks: all hooks use `process.stdin.on('end', ...)` pattern + `process.exit(0)` — never exit 2 in telemetry
- Append-only writes in bash: `echo "..." >> file` guarded by `[ "${CONJURE_TELEMETRY:-0}" = "1" ]`

### Integration Points
- `templates/settings.json.tmpl` `"hooks"` object: add two new entries under `PreToolUse` (Skill matcher) and a new `UserPromptExpansion` top-level key
- `scripts/audit-setup.sh` after the `[ "$FAIL" -gt 0 ]` exit block is the wrong place — the retire-list section must come BEFORE the `[ "$FAIL" -gt 0 ] && exit 2` line, after the cost section
- `cli/conjure` `cmd_audit()`: currently passes `CONJURE_COST` and `CONJURE_EXACT` — add `CONJURE_RETIRE` in same `env` block call

</code_context>

<specifics>
## Specific Ideas

- The retire-list should make it viscerally obvious which skills are dead weight: `[retire?]` marker plus 0 in the Loads column
- `TELEMETRY.md` must make the no-egress guarantee explicit and verifiable — not just "we promise", but "run this grep to verify"
- The `DO_NOT_TRACK` check should be the FIRST thing in the hook (before `CONJURE_TELEMETRY` check) per convention

</specifics>

<deferred>
## Deferred Ideas

- Aggregate retire-list across multiple projects (requires a central store — out of scope, local-only by design)
- Auto-prune skills with 0 loads (`conjure prune-skills`) — v0.4.0 feature
- Telemetry dashboard / visualization — out of scope for v0.3.0
- `CONJURE_RETIRE_DAYS` env override — acceptable to hardcode 30 days for now; add if time permits

</deferred>

---

*Phase: 7-Skill-Firing-Telemetry*
*Context gathered: 2026-05-25*
