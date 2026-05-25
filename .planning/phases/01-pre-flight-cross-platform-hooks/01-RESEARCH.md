# Phase 1: Pre-flight & Cross-Platform Hooks - Research

**Researched:** 2026-05-24
**Domain:** POSIX bash CLI tooling, Node.js hook wiring, cross-platform shell scripting
**Confidence:** HIGH (all findings from direct codebase inspection + verified npm registry)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Always emit `node .claude/hooks/*.mjs` for all hooks on all platforms — no OS branching in init. Single `settings.json` template, no conditional paths.
- **D-02:** Use relative paths: `node .claude/hooks/foo.mjs` (matches Claude Code's project-root execution model).
- **D-03:** `node` is a **required** dep — `conjure init` blocks with a non-zero exit if node is missing.
- **D-04:** **Required (block init):** `node`, `git`
- **D-05:** **Optional (warn, continue):** `jq`, `rg`, `shellcheck`
- **D-06:** `shellcheck` is checked and warned about (audit degrades gracefully without it), not silently ignored.
- **D-07:** `conjure preflight` is a **user-facing subcommand** — exposed in CLI dispatch, users and CI scripts can invoke it standalone.
- **D-08:** `scripts/preflight.sh` is called by: `conjure init`, `conjure audit`, `conjure preflight` subcommand, and `tests/run.sh`. No inline duplication.
- **D-09:** `conjure init` exits non-zero if preflight finds a required dep missing; `conjure audit` likewise blocks.
- **D-10:** One copy-pasteable line per missing dep, per detected package manager. Example:
  ```
  ✗ node missing (required)
    macOS:   brew install node
    Linux:   apt install nodejs
    Windows: winget install OpenJS.NodeJS
  ```
- **D-11:** OS detection via `uname -s` (Darwin → macOS, Linux → Linux) + `$OSTYPE` check for msys/cygwin (Git Bash on Windows) + `uname -r` grep for "Microsoft" (WSL).
- **D-12:** Never auto-install. Report and exit (required) or report and continue (optional).

### Claude's Discretion
- Exact dep version requirements (minimum node version, minimum git version) — check what Claude Code itself requires and match.
- Whether `graphify` and `ast-grep` are still listed as optional power tools in preflight output (low priority).
- Output formatting details (emoji vs plain ASCII prefix for required/optional).

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SAFE-03 | Generated hook wiring runs on native Windows — init emits portable `node .mjs` hook wiring instead of hardwired `bash .claude/hooks/*.sh` | Found: `templates/settings.json.tmpl` hardwires bash for 4 hooks; `templates/hooks-nodejs/*.mjs` exists for all 5 hooks and is not yet wired. Fix: replace bash commands with `node` commands in template and update `init-project.sh` to copy `.mjs` files. |
| SAFE-04 | Pre-flight check reports each missing dependency with a copy-pasteable, OS-detected install fix-it and never auto-installs | Found: `cmd_preflight()` in `cli/conjure:169` always emits brew regardless of OS, never blocks, and treats git/jq/rg as a flat list. Fix: extract to `scripts/preflight.sh` with required/optional split, OS detection, and per-manager fix-it lines. |
</phase_requirements>

---

## Summary

Phase 1 fixes two live bugs and extracts reusable infrastructure. Both bugs are in existing code that is currently shipping to users.

**Bug 1 (SAFE-03):** `templates/settings.json.tmpl` hardwires `bash .claude/hooks/*.sh` commands for all four wired hooks. On native Windows (where `bash` is not in PATH outside Git Bash), these hooks silently no-op — Claude Code executes the command, gets an error, and continues. The fix is to replace every `bash .claude/hooks/*.sh` command with `node .claude/hooks/*.mjs` in the template, update `scripts/init-project.sh` to copy `.mjs` files instead of `.sh` files, and wire the previously-omitted `pre-commit-quality-gate.mjs` hook. No OS branching is needed: Claude Code requires Node.js on all platforms per its own engine requirement.

**Bug 2 (SAFE-04):** `cmd_preflight()` at `cli/conjure:169` is a 19-line inline function that (a) puts required deps (git) in the same bucket as optional deps (jq, rg), (b) emits `brew install` regardless of OS, (c) never returns non-zero, and (d) checks `graphify`/`ast-grep` as a separate loop. Extract to `scripts/preflight.sh` with: OS detection, required vs optional dep split, per-OS fix-it lines, non-zero exit on required-dep failure, and a `conjure preflight` user-facing subcommand.

**Primary recommendation:** Implement in two focused tasks — (1) extract and harden `scripts/preflight.sh`, wire it into CLI and tests; (2) update `templates/settings.json.tmpl` and `scripts/init-project.sh` for node hook wiring.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dep presence detection | CLI / scripts | — | Pure bash `command -v`; no framework layer needed |
| OS detection | CLI / scripts | — | `uname -s` + `$OSTYPE` + `uname -r` in bash |
| Fix-it message emit | CLI / scripts | — | Stdout/stderr from preflight.sh |
| Hook wiring | Template layer | init-project.sh | Template defines JSON; init copies .mjs files |
| Hook execution | Claude Code runtime | Node.js | CC executes the `command` string; Node runs the .mjs |
| Required-dep block | scripts/preflight.sh | cli/conjure | preflight.sh exits non-zero; CLI propagates it |
| Optional-dep warn | scripts/preflight.sh | — | Warn and continue; no CLI-level action |

---

## Standard Stack

No external packages required. Phase 1 is pure bash + Node.js stdlib.

### Core (all already available)
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | ≥3.2 | Script runtime for preflight.sh and CLI | Project convention; all existing scripts use `#!/usr/bin/env bash` |
| node | ≥18.0.0 | Hook runtime; required dep | Claude Code engine requirement [VERIFIED: npm registry `@anthropic-ai/claude-code engines: { node: '>=18.0.0' }`] |
| git | ≥2.0 | VCS; required dep | Conjure clones itself via git; no explicit minimum in CLAUDE.md [ASSUMED: 2.0 as safe floor] |
| jq | any | JSON validation in audit, optional dep | Used in audit-setup.sh and tests/run.sh already |

### Package Legitimacy Audit

> Phase 1 installs **zero new external packages**. All changes are to existing bash scripts and JSON templates. No npm install / pip install / brew install steps occur during implementation. This section is therefore not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
Developer runs: conjure init / conjure audit / conjure preflight
        |
        v
  cli/conjure (bash dispatcher)
        |
        +--> cmd_preflight() stub
                    |
                    v
          scripts/preflight.sh  <---- also called by tests/run.sh directly
                    |
          OS detection (uname -s / $OSTYPE / uname -r)
                    |
          +---------+---------+
          |                   |
   Required deps         Optional deps
   (node, git)           (jq, rg, shellcheck)
          |                   |
   missing? → exit 1     missing? → warn, continue
   present? → continue
                    |
          emit per-OS fix-it lines
          (brew / apt / winget)
                    |
          exit 0 (all present or only optional missing)
```

```
conjure init (after preflight passes)
        |
        v
  scripts/init-project.sh
        |
        +--> copy templates/hooks-nodejs/*.mjs → .claude/hooks/
        +--> copy templates/settings.json.tmpl → .claude/settings.json
                    |
                    v
          .claude/settings.json (node commands, relative paths)
                    |
          Claude Code reads on startup
                    |
          executes: node .claude/hooks/post-edit-format.mjs
                    node .claude/hooks/pre-bash-block-destructive.mjs
                    node .claude/hooks/pre-commit-quality-gate.mjs
                    node .claude/hooks/stop-compound-engineering.mjs
                    node .claude/hooks/session-start-context.mjs
```

### Recommended Project Structure (no new dirs)

```
scripts/
├── preflight.sh          # NEW: extracted + hardened dep checker
├── init-project.sh       # MOD: copy .mjs hooks, not .sh
├── audit-setup.sh        # MOD: call preflight.sh, check .mjs hooks
└── (existing scripts)
templates/
├── hooks-nodejs/         # unchanged — 5 .mjs files already complete
│   ├── post-edit-format.mjs
│   ├── pre-bash-block-destructive.mjs
│   ├── pre-commit-quality-gate.mjs
│   ├── session-start-context.mjs
│   └── stop-compound-engineering.mjs
└── settings.json.tmpl    # MOD: bash → node commands
cli/
└── conjure               # MOD: cmd_preflight stub, add preflight dispatch
tests/
└── run.sh                # MOD: add preflight test section
```

### Pattern 1: Standalone Preflight Script

**What:** A self-contained bash script that can be sourced or executed directly. Returns 0 if OK, non-zero if a required dep is missing.

**When to use:** Whenever a caller needs to gate on dep availability before proceeding.

**Example:**
```bash
# Source: direct codebase inspection (install.sh:22-28, scripts/install-mcp-stack.sh:15-20)
#!/usr/bin/env bash
# scripts/preflight.sh — dep check with OS-detected fix-its
set -uo pipefail

# --- OS detection (D-11) ---
_os_detect() {
  local s; s="$(uname -s 2>/dev/null)"
  case "$s" in
    Darwin) echo "macos" ;;
    Linux)
      if uname -r 2>/dev/null | grep -qi "microsoft"; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows-gitbash" ;;
    *)
      case "${OSTYPE:-}" in
        msys*|cygwin*) echo "windows-gitbash" ;;
        *) echo "unknown" ;;
      esac ;;
  esac
}

# --- Fix-it lines (D-10) ---
_fixup() {
  local dep="$1" os="$2"
  case "$dep:$os" in
    node:macos)             echo "    macOS:   brew install node" ;;
    node:linux|node:wsl)    echo "    Linux:   apt install nodejs" ;;
    node:windows-gitbash)   echo "    Windows: winget install OpenJS.NodeJS" ;;
    git:macos)              echo "    macOS:   brew install git" ;;
    git:linux|git:wsl)      echo "    Linux:   apt install git" ;;
    git:windows-gitbash)    echo "    Windows: winget install Git.Git" ;;
    jq:macos)               echo "    macOS:   brew install jq" ;;
    jq:linux|jq:wsl)        echo "    Linux:   apt install jq" ;;
    jq:windows-gitbash)     echo "    Windows: winget install jqlang.jq" ;;
    rg:macos)               echo "    macOS:   brew install ripgrep" ;;
    rg:linux|rg:wsl)        echo "    Linux:   apt install ripgrep" ;;
    rg:windows-gitbash)     echo "    Windows: winget install BurntSushi.ripgrep.MSVC" ;;
    shellcheck:macos)       echo "    macOS:   brew install shellcheck" ;;
    shellcheck:linux|shellcheck:wsl) echo "    Linux: apt install shellcheck" ;;
    shellcheck:windows-gitbash) echo "    Windows: winget install koalaman.shellcheck" ;;
    *) echo "    see: https://github.com/mohandoz/conjure#requirements" ;;
  esac
}
```

### Pattern 2: Stub-Delegate in CLI

**What:** `cmd_preflight()` in `cli/conjure` becomes a thin delegator to `scripts/preflight.sh`. The calling pattern (`cmd_preflight || return 1`) in `cmd_init` stays unchanged.

**When to use:** Keep CLI function names stable; move implementation to standalone script.

**Example:**
```bash
# Source: cli/conjure current structure (lines 67, 169-188)
cmd_preflight() {
  bash "$CONJURE_HOME/scripts/preflight.sh"
}
# cmd_init already calls: cmd_preflight || return 1
# This calling pattern is preserved exactly.
```

### Pattern 3: Node Hook Command in settings.json

**What:** Replace `bash .claude/hooks/foo.sh "arg"` with `node .claude/hooks/foo.mjs`. The `.mjs` hooks read their input from `process.env.CLAUDE_*` env vars (set by Claude Code) with `process.argv[2]` as fallback — so no arg passing is needed.

**When to use:** All hook commands in settings.json.tmpl.

**Example:**
```json
// Source: templates/hooks-nodejs/README.md (verified pattern)
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "node .claude/hooks/post-edit-format.mjs" }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "node .claude/hooks/pre-bash-block-destructive.mjs" },
          { "type": "command", "command": "node .claude/hooks/pre-commit-quality-gate.mjs" }
        ]
      }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "node .claude/hooks/stop-compound-engineering.mjs" }] }
    ],
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "node .claude/hooks/session-start-context.mjs" }] }
    ]
  }
}
```

Note: `pre-commit-quality-gate.mjs` is currently absent from `settings.json.tmpl`. Phase 1 adds it as a second hook in the `PreToolUse[Bash]` array. Claude Code runs all hooks in an array that match — the `.mjs` internally skips non-`git commit` commands via `if (!/^git\s+commit/.test(cmd)) process.exit(0)`.

### Anti-Patterns to Avoid

- **Keeping `cmd_preflight` as an inline function with logic:** Any new dep or OS support requires editing the CLI. Extract to `scripts/preflight.sh` instead.
- **OS branching in settings.json.tmpl:** A single template with `node` works on all platforms. No `if Windows then ... else ...` logic in init.
- **Using `mapfile` or `readarray` in preflight.sh:** macOS ships bash 3.2 at `/bin/bash`; `#!/usr/bin/env bash` may or may not find a newer bash. The existing project scripts avoid bash 4+ features (confirmed by grep) — continue the pattern.
- **Passing args to node hook commands:** The `.mjs` hooks read `process.env.CLAUDE_FILE_PATH` and `process.env.CLAUDE_COMMAND` directly. The old bash pattern passed `"$CLAUDE_FILE_PATH"` as an arg — this is unnecessary with node and creates `$VARIABLE` expansion confusion in JSON strings.
- **Checking `nodejs` instead of `node` in preflight:** `#!/usr/bin/env node` (used by all .mjs hooks) resolves `node`, not `nodejs`. Check `command -v node`. On Ubuntu/Debian, modern `apt install nodejs` creates both `nodejs` and `node` symlinks. If only `nodejs` exists (very old Ubuntu), the hooks will silently fail — preflight catches this by checking `node`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OS detection | Custom `uname` wrappers | Direct `uname -s` + `$OSTYPE` + `uname -r` grep | D-11 is the locked approach; sufficient for the 4 cases (macOS, Linux, WSL, Git Bash) |
| Node version check | Custom semver parser | `node --version` output + `printf '%s\n' ... | sort -V` comparison | Unnecessary — Claude Code enforces ≥18 at install time; preflight only needs to confirm `node` exists |
| Hook invocation dispatch | Custom OS-branch wrapper | `node .claude/hooks/foo.mjs` directly | Hooks already use `process.env.CLAUDE_*` — no wrapper needed |
| Dep fix-it database | External lookup | Hardcoded case statement in preflight.sh | Small fixed set (5 deps × 3 OS = 15 lines); static table is correct |

---

## Common Pitfalls

### Pitfall 1: `$OSTYPE` Is Not Set Under All Shells

**What goes wrong:** `$OSTYPE` is set by bash (it's a bash variable), not by POSIX sh. On some minimal Linux Docker containers, bash may not set it.

**Why it happens:** `OSTYPE` is a bash-internal variable, not exported from the shell's environment.

**How to avoid:** Always primary-detect via `uname -s`. Use `$OSTYPE` only as secondary check for the msys/cygwin case. The detection order: `uname -s` first → `$OSTYPE` only if uname is inconclusive.

**Warning signs:** `$OSTYPE` evaluates to empty string despite running bash.

### Pitfall 2: `set -e` and `command -v` Interaction

**What goes wrong:** Under `set -eo pipefail`, `command -v missing_tool` returns non-zero and aborts the script before you can handle the failure gracefully.

**Why it happens:** `set -e` exits on any non-zero exit code, including probe commands.

**How to avoid:** Use `command -v tool >/dev/null 2>&1 || <handle>` pattern (the `|| <handle>` suppresses the abort). The existing `cmd_preflight` already uses this pattern correctly. Maintain it in `scripts/preflight.sh`. Existing scripts use `set -uo pipefail` (not `-e`) — which is safer for this use case.

**Warning signs:** Script exits silently after checking a dep that isn't installed, before emitting the fix-it message.

### Pitfall 3: `$CLAUDE_FILE_PATH` Variable Expansion in JSON

**What goes wrong:** If you write `"command": "node .claude/hooks/foo.mjs \"$CLAUDE_FILE_PATH\""` in settings.json, this is a JSON string literal — the `$CLAUDE_FILE_PATH` is not a shell variable, it's text. Claude Code expands it via its own template mechanism.

**Why it happens:** The existing bash hooks in settings.json.tmpl do pass `"$CLAUDE_FILE_PATH"` as a shell argument, which works because bash performs the expansion. The node hooks don't need the arg because they read `process.env.CLAUDE_FILE_PATH` directly.

**How to avoid:** Do not pass `"$CLAUDE_FILE_PATH"` as an argument to node hooks. The `.mjs` files already fall back to `process.env.CLAUDE_FILE_PATH` when no argv[2] is provided. Use `"node .claude/hooks/post-edit-format.mjs"` with no argument (verified in hooks-nodejs/README.md).

**Warning signs:** Node hooks receive the literal string `"$CLAUDE_FILE_PATH"` as argv[2] instead of the file path.

### Pitfall 4: audit-setup.sh Only Checks `.sh` Hooks

**What goes wrong:** After Phase 1, generated hooks are `.mjs` files. `audit-setup.sh` line 102 runs `find .claude/hooks -maxdepth 1 -name '*.sh'` — it finds nothing and emits no hook warnings, giving a false green on an empty hooks dir.

**Why it happens:** The audit script was written before the mjs hooks existed.

**How to avoid:** Update `audit-setup.sh` to check `.mjs` hooks for existence and verify that `settings.json` references them correctly. The check should be: verify that `.mjs` files referenced in settings.json exist, not that any `.sh` files are executable.

**Warning signs:** `conjure audit` reports "✓" on hooks even though `.claude/hooks/` is empty.

### Pitfall 5: init-project.sh Still Copies `.sh` Hooks

**What goes wrong:** `scripts/init-project.sh` line 46 copies from `templates/hooks/*.sh`. After Phase 1 this produces a `.claude/hooks/` with bash hooks, but `settings.json` references `.mjs` files — Claude Code tries to run `node .claude/hooks/post-edit-format.mjs` but the file doesn't exist.

**Why it happens:** The hook copy source and the settings.json template are currently out of sync (bash templates + bash settings).

**How to avoid:** Update `init-project.sh` hook copy block to iterate over `templates/hooks-nodejs/*.mjs`. Note: `.mjs` files do not need `chmod +x` since they're invoked via `node file.mjs`, not as executables.

**Warning signs:** Hooks silently no-op after init on any platform (`.mjs` files missing).

### Pitfall 6: `scripts/preflight.sh` Must Not Depend on CLI State

**What goes wrong:** If `preflight.sh` sources variables from the CLI (e.g., `$CONJURE_HOME`), it cannot be called standalone from `tests/run.sh` without setting up the CLI environment first.

**Why it happens:** Scripts extracted from a monolithic function tend to carry implicit dependencies.

**How to avoid:** `scripts/preflight.sh` must be fully self-contained. No sourced variables. Any path it needs should be derived from `$(dirname "$0")` or passed as arguments. Confirmed by CONTEXT.md: "pure POSIX bash, no sourced variables from the CLI."

---

## Code Examples

### Complete OS Detection Function

```bash
# Source: synthesized from install.sh:22-28, D-11 locked pattern
# Works in bash 3.2+ (macOS default)
_detect_os() {
  local uname_s uname_r
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  uname_r="$(uname -r 2>/dev/null || echo unknown)"
  case "$uname_s" in
    Darwin) printf "macos" ;;
    Linux)
      if printf '%s' "$uname_r" | grep -qi "microsoft"; then
        printf "wsl"
      else
        printf "linux"
      fi ;;
    MINGW*|MSYS*|CYGWIN*) printf "windows-gitbash" ;;
    *)
      case "${OSTYPE:-}" in
        msys*|cygwin*) printf "windows-gitbash" ;;
        *)             printf "unknown" ;;
      esac ;;
  esac
}
```

### Required Dep Check (Block Pattern)

```bash
# Source: synthesized from cmd_preflight existing pattern + D-04/D-09 decisions
REQUIRED_FAILED=0
for dep in node git; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    printf "  ✗ %s missing (required)\n" "$dep"
    _fixup "$dep" "$(_detect_os)"
    REQUIRED_FAILED=1
  else
    printf "  ✓ %s\n" "$dep"
  fi
done
[ "$REQUIRED_FAILED" -eq 1 ] && exit 1
```

### Optional Dep Check (Warn Pattern)

```bash
# Source: synthesized from cmd_preflight existing pattern + D-05/D-06 decisions
for dep in jq rg shellcheck; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    printf "  ⚠ %s not found (optional — some features degraded)\n" "$dep"
    _fixup "$dep" "$(_detect_os)"
  else
    printf "  ✓ %s\n" "$dep"
  fi
done
```

### CLI Dispatch Addition

```bash
# Source: cli/conjure dispatch block (lines 199-209) — add one case
case "${1:-help}" in
  init)            shift; cmd_init "$@"            ;;
  preflight)       shift; cmd_preflight "$@"       ;;   # NEW
  # ... rest of dispatch ...
esac
```

### settings.json.tmpl Full Hooks Replacement

```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [
        { "type": "command", "command": "node .claude/hooks/post-edit-format.mjs" }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "node .claude/hooks/pre-bash-block-destructive.mjs" },
        { "type": "command", "command": "node .claude/hooks/pre-commit-quality-gate.mjs" }
      ]
    }
  ],
  "Stop": [
    {
      "hooks": [
        { "type": "command", "command": "node .claude/hooks/stop-compound-engineering.mjs" }
      ]
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        { "type": "command", "command": "node .claude/hooks/session-start-context.mjs" }
      ]
    }
  ]
}
```

### init-project.sh Hook Copy Update

```bash
# Source: scripts/init-project.sh:44-53 — replace .sh loop with .mjs loop
# 4. Copy hooks (node .mjs — works on all platforms including Windows)
for hook in "$KIT"/templates/hooks-nodejs/*.mjs; do
  name=$(basename "$hook")
  if [ ! -f ".claude/hooks/$name" ]; then
    cp "$hook" ".claude/hooks/$name"
    # .mjs files invoked via `node` — no chmod +x needed
    echo "  ✓ created .claude/hooks/$name"
  fi
done
```

### tests/run.sh Preflight Section Addition

```bash
# Source: tests/run.sh pattern (lines 14-15, 26) — add after smoke tests
echo
echo "▸ Preflight script"
if bash scripts/preflight.sh >/dev/null 2>&1; then
  pass "scripts/preflight.sh: exits 0 (all required deps present)"
else
  fail "scripts/preflight.sh: non-zero exit (required dep missing in test env?)"
fi

# Verify required-dep block: strip node from PATH, expect non-zero
if PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "$(dirname "$(command -v node)")" | tr '\n' ':')" \
   bash scripts/preflight.sh >/dev/null 2>&1; then
  fail "scripts/preflight.sh: did NOT block when node missing"
else
  pass "scripts/preflight.sh: correctly blocks when node missing"
fi
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bash hooks in settings.json | Node.js hooks in settings.json | Phase 1 (this) | Hooks fire on native Windows; no bash dependency |
| Inline cmd_preflight with brew-only fix-its | Standalone scripts/preflight.sh with OS detection | Phase 1 (this) | Reusable, testable, OS-correct |
| git/jq/rg all treated as "recommended" | node+git required, jq+rg+shellcheck optional | Phase 1 (this) | init blocks on missing node; audit degrades gracefully |

**Deprecated/outdated after Phase 1:**
- `templates/hooks/*.sh` as the init-generated hook set: stays as reference/fallback but `init-project.sh` no longer copies them.
- Inline `cmd_preflight()` logic: shell becomes a stub that delegates to `scripts/preflight.sh`.

---

## Open Questions (RESOLVED)

1. **Should pre-commit-quality-gate.mjs be wired by default?**
   - What we know: It exists in `templates/hooks-nodejs/`. The bash version is not in `settings.json.tmpl`. The mjs version internally guards itself with `if (!/^git\s+commit/.test(cmd)) process.exit(0)`.
   - What's unclear: Was it intentionally omitted from the template, or was it an oversight?
   - Recommendation: Wire it (Phase 1 goal says "wires them, not rewrites them" — "them" = all 5 .mjs hooks). It does no harm when not running `git commit`.

2. **Should `graphify` and `ast-grep` remain in optional dep output?**
   - What we know: The current `cmd_preflight` checks them; they're listed in `install.sh` as optional. Marked as Claude's Discretion in CONTEXT.md.
   - Recommendation: Keep them as a separate "power tools" block after the main optional deps — clearly labeled "(optional power tools — not required for core harness)".

3. **Minimum git version to require?**
   - What we know: Claude Code specifies `node >=18.0.0` [VERIFIED] but no explicit git minimum. CLAUDE.md says "Claude Code ≥2.1.117." Confirmed running: git 2.54.0.
   - Recommendation [ASSUMED]: Require git ≥2.0 (released 2014, universally available). No version check needed in preflight — just presence check. Git 2.0 supports all operations Conjure uses.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | scripts/preflight.sh, cli/conjure | ✓ | system bash 3.2+ / env bash 5.x | — (bash is the runtime) |
| node | hooks runtime; required dep | ✓ | v24.15.0 (dev machine) | — blocks init |
| git | conjure clone + required dep | ✓ | 2.54.0 | — blocks init |
| jq | audit-setup.sh JSON validation | ✓ | 1.8.1 | audit warns, continues |
| rg | optional dep | ✓ | 15.1.0 | skills/code-graph degrades |
| shellcheck | optional dep | ✗ (not found on dev machine) | — | audit warns, continues |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** shellcheck (not installed on dev machine — test environment should expect this optional-dep warn path to be exercised).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Hand-rolled bash (`tests/run.sh`) — project standard per CLAUDE.md |
| Config file | none — tests/run.sh is self-contained |
| Quick run command | `bash tests/run.sh` |
| Full suite command | `bash tests/run.sh` (single suite) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SAFE-04 | `scripts/preflight.sh` exits 0 when all deps present | smoke | `bash tests/run.sh` (new section) | ❌ Wave 0 |
| SAFE-04 | `scripts/preflight.sh` exits non-zero when `node` missing | unit | `bash tests/run.sh` (PATH manipulation) | ❌ Wave 0 |
| SAFE-04 | `scripts/preflight.sh` exits 0 when only optional dep missing | unit | `bash tests/run.sh` (PATH manipulation) | ❌ Wave 0 |
| SAFE-04 | Fix-it output contains OS-specific package manager name | output | `bash tests/run.sh` (grep fix-it output) | ❌ Wave 0 |
| SAFE-03 | `templates/settings.json.tmpl` has no `bash .claude/hooks/` strings | lint | `bash tests/run.sh` (grep assertion) | ❌ Wave 0 |
| SAFE-03 | `templates/settings.json.tmpl` has `node .claude/hooks/` strings | lint | `bash tests/run.sh` (grep assertion) | ❌ Wave 0 |
| SAFE-03 | `scripts/preflight.sh` is executable | existing | `bash tests/run.sh` line 29-33 (finds all scripts/*.sh) | ✅ (auto-covered once file created) |

### Sampling Rate

- **Per task commit:** `bash tests/run.sh` (< 5 seconds)
- **Per wave merge:** `bash tests/run.sh`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/preflight.sh` — does not exist yet; must be created in Wave 1
- [ ] `tests/run.sh` preflight section — add after audit script self-test block
- [ ] Template lint assertions in `tests/run.sh` — grep that settings.json.tmpl contains `node .claude/hooks/` and does NOT contain `bash .claude/hooks/`

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 1 |
|-----------|-------------------|
| POSIX bash + Node.js `.mjs` hooks — stay cross-platform; no heavy runtime deps | `scripts/preflight.sh` uses `#!/usr/bin/env bash`; no npm packages |
| Safety: backup-before-mutate on every change; no `curl \| sh`; hooks `exit 2` never `exit 1` | `preflight.sh` must never auto-install; hooks already use exit 2 |
| Hooks `exit 2` (never `exit 1`) | `preflight.sh` is not a hook — it may use `exit 1` for required-dep failure |
| Claude Code ≥2.1.117; `@imports` forbidden in CLAUDE.md | Not directly relevant to Phase 1 implementation |
| `dependencies: {}` empty | Phase 1 installs no npm packages |
| Extend hand-rolled `tests/run.sh`; bats-core only at unit level | Add a preflight section to `tests/run.sh`; no new test framework |
| `lib/` doesn't exist yet — Phase 2 creates `lib/mutate.sh` | Phase 1 uses only `scripts/`; do not create `lib/` |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | git ≥2.0 is a safe minimum version floor (no explicit git minimum in Claude Code docs or CLAUDE.md) | Standard Stack | Low risk — git 2.0 is from 2014; any modern system has ≥2.28. Only risk: user on ancient system with git 1.x, which Conjure already implicitly requires for clone |
| A2 | `pre-commit-quality-gate.mjs` was omitted from settings.json.tmpl by oversight, not intentionally | Code Examples / Open Questions | Low risk — the hook guards itself internally; wiring it adds no overhead when not committing |
| A3 | `apt install nodejs` on Ubuntu 20.04+ creates both `nodejs` and `node` symlinks | Common Pitfalls (Pitfall 5) | Medium risk — if a user's old Ubuntu only has `nodejs`, `#!/usr/bin/env node` fails. Preflight checks `node`; users get a fix-it. The only risk is if the fix-it says `apt install nodejs` but that doesn't create `node` on their version |

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `cli/conjure:169-188` — exact current `cmd_preflight()` implementation
- Direct codebase inspection: `templates/settings.json.tmpl` — exact hook command strings to replace
- Direct codebase inspection: `templates/hooks-nodejs/*.mjs` — all 5 hooks read env vars, not argv, so no arg passing needed
- Direct codebase inspection: `scripts/init-project.sh:44-53` — current `.sh` copy loop to replace with `.mjs`
- Direct codebase inspection: `scripts/audit-setup.sh:97-103` — current `.sh`-only hook check to update
- Direct codebase inspection: `tests/run.sh` — structure and pattern for adding preflight section
- `npm view @anthropic-ai/claude-code engines` — `{ node: '>=18.0.0' }` [VERIFIED: npm registry]

### Secondary (MEDIUM confidence)
- `templates/hooks-nodejs/README.md` — three rules for universal hooks, exact command format
- `install.sh:22-28` — existing dep check pattern using `command -v` loops

### Tertiary (LOW confidence)
- winget package IDs (OpenJS.NodeJS, Git.Git, jqlang.jq, BurntSushi.ripgrep.MSVC, koalaman.shellcheck) [ASSUMED — not verified against winget registry in this session]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all existing tools verified on dev machine
- Architecture: HIGH — all changes are in existing files with known structure; all file contents read directly
- Pitfalls: HIGH — most pitfalls derived from direct code inspection (wrong-file-extension audit check, missing mjs copy, inline dependency)

**Research date:** 2026-05-24
**Valid until:** 2026-06-24 (stable bash/node patterns; winget IDs [ASSUMED] may drift)
