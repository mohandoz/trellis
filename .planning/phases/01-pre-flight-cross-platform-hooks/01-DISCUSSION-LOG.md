# Phase 1: Pre-flight & Cross-Platform Hooks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-24
**Phase:** 1-Pre-flight & Cross-Platform Hooks
**Areas discussed:** Hook wiring strategy, Required vs optional deps, Preflight as subcommand, Install fix-it format

---

## Hook Wiring Strategy

**Q1: How should `conjure init` wire hooks in the generated `settings.json`?**

| Option | Description | Selected |
|--------|-------------|----------|
| Node everywhere | Always emit `node .claude/hooks/*.mjs` for all platforms. `.mjs` hooks already exist. Simpler: one template. | ✓ |
| OS-branched at init time | Detect OS during init, emit `bash ...` on POSIX, `node ...` on Windows. Two code paths. | |
| Runtime wrapper | Wrapper detects at hook-runtime whether bash or node should run. Extra indirection. | |

**User's choice:** Node everywhere
**Notes:** `.mjs` hooks already exist in `templates/hooks-nodejs/` — no rewrite needed.

---

**Q2: Does node become a required dep?**

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, required — block | Hooks can't fire without node. Matches SAFE-04. | ✓ |
| No, optional — warn only | Init proceeds but hooks silently no-op. Contradicts goal. | |

**User's choice:** Yes, node is required — block
**Notes:** Consistent with node-everywhere strategy.

---

**Q3: Relative or absolute paths for hook commands?**

| Option | Description | Selected |
|--------|-------------|----------|
| Relative `node .claude/hooks/foo.mjs` | Simple, matches current bash pattern, Claude Code runs hooks from project root. | ✓ |
| Absolute via env var | More resilient if cwd changes but env var name may vary across CC versions. | |

**User's choice:** Relative
**Notes:** Mirrors `bash .claude/hooks/*.sh` pattern in current template.

---

## Required vs Optional Deps

**Q4: Which deps block vs warn?**

| Option | Description | Selected |
|--------|-------------|----------|
| node + git required; jq + rg optional | node: hooks need it. git: init writes to repo. jq/rg: audit tools, not init-critical. | ✓ |
| node + git + jq required; rg optional | jq required earlier catches silent audit degradation. | |
| node only required | Minimal blocking. | |

**User's choice:** node + git required; jq + rg optional
**Notes:** jq/rg absent causes audit degradation, not init failure.

---

**Q5: Should `shellcheck` be checked?**

| Option | Description | Selected |
|--------|-------------|----------|
| Optional — warn only | Audit degrades gracefully. Not needed for init. | ✓ |
| Required for audit subcommand only | Adds complexity to distinguish calling context. | |
| Not checked at all | User gets confusing mid-audit failure. | |

**User's choice:** Optional — warn only
**Notes:** Preflight checks shellcheck presence and warns; audit skips shellcheck step if absent.

---

## Preflight as Subcommand

**Q6: User-facing or internal only?**

| Option | Description | Selected |
|--------|-------------|----------|
| User-facing subcommand | Users + CI can run `conjure preflight` standalone. Already has dispatch slot. | ✓ |
| Internal only | Strip dispatch; fewer surface area but loses debugging tool. | |

**User's choice:** User-facing subcommand
**Notes:** `cmd_preflight` dispatch already exists in CLI.

---

**Q7: Which commands call `scripts/preflight.sh`?**

| Option | Description | Selected |
|--------|-------------|----------|
| init + audit + preflight subcommand | Both mutation-heavy commands check env first. `tests/run.sh` also invokes directly. | ✓ |
| Only init | Simpler but audit can silently degrade. | |
| Only preflight subcommand | Maximizes silent failure risk. | |

**User's choice:** init + audit + preflight subcommand (+ tests/run.sh)
**Notes:** Chokepoint model — one script, called everywhere.

---

## Install Fix-it Format

**Q8: How to format missing-dep fix-its?**

| Option | Description | Selected |
|--------|-------------|----------|
| One line per dep, per package manager | Each dep gets brew / apt / winget lines. Copy-pasteable. | ✓ |
| Grouped per OS, all missing deps one line | Fewer lines but harder to parse required vs optional. | |
| Interactive prompt | Breaks non-TTY / CI usage. | |

**User's choice:** One line per dep, per package manager
**Notes:** Output must be golden-file testable in Phase 4.

---

**Q9: OS detection approach?**

| Option | Description | Selected |
|--------|-------------|----------|
| uname + OSTYPE heuristic | `uname -s` for Darwin/Linux; `$OSTYPE` for msys/cygwin; `uname -r` grep for WSL. | ✓ |
| Explicit --os flag | Clean for CI but adds friction for interactive use. | |
| Show all three package managers always | Always correct but verbose. | |

**User's choice:** uname + OSTYPE heuristic
**Notes:** Native Windows can't run bash — node hook wiring addresses that separately. WSL users get Linux fix-its.

---

## Claude's Discretion

- Minimum node/git version requirements — check what Claude Code itself requires.
- Whether `graphify` / `ast-grep` remain listed as optional power tools in preflight output.
- Output formatting details (emoji vs plain ASCII prefix for required/optional lines).

## Deferred Ideas

None — discussion stayed within phase scope.
