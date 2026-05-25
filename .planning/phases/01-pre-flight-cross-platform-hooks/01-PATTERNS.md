# Phase 1: Pre-flight & Cross-Platform Hooks - Pattern Map

**Mapped:** 2026-05-24
**Files analyzed:** 6
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/preflight.sh` | utility | request-response | `install.sh` lines 22-29 + `cli/conjure` lines 169-188 | role-match (split: install.sh has the command-v loop; cli/conjure has the dep list) |
| `cli/conjure` | controller | request-response | `cli/conjure` lines 199-209 (dispatch) + lines 165-167 (stub pattern) | exact — add one case + replace function body |
| `templates/settings.json.tmpl` | config | — | `templates/settings.json.tmpl` lines 41-84 (current hook block) | exact — same file, replace command strings |
| `scripts/init-project.sh` | utility | file-I/O | `scripts/init-project.sh` lines 46-53 (hook copy loop) | exact — same file, replace loop source path |
| `scripts/audit-setup.sh` | utility | request-response | `scripts/audit-setup.sh` lines 97-103 (hook check block) | exact — same file, replace `.sh` glob with `.mjs` logic |
| `tests/run.sh` | test | request-response | `tests/run.sh` lines 96-101 (audit self-test section) | role-match — same section/pass/fail pattern, new subject |

---

## Pattern Assignments

### `scripts/preflight.sh` (NEW — utility, request-response)

**Primary analog:** `install.sh` lines 22-29 (command-v loop + exit pattern)
**Secondary analog:** `cli/conjure` lines 169-188 (existing cmd_preflight to be extracted and hardened)

**Shebang + set flags pattern** (`install.sh` lines 1, 9 / `scripts/audit-setup.sh` lines 1, 8):
```bash
#!/usr/bin/env bash
set -uo pipefail
```
Note: Use `set -uo pipefail`, NOT `set -euo pipefail`. The `-e` flag causes `command -v missing_tool` to abort the script before the fix-it message can be emitted. All existing project scripts that do dep-checking use `-uo pipefail` (confirmed: `install-mcp-stack.sh` line 8, `audit-setup.sh` line 8). `init-project.sh` is the only one using `-euo pipefail` because it never checks for optional deps.

**Required dep check pattern** (`install.sh` lines 22-25):
```bash
# Source: install.sh:22-25
for tool in git bash; do
  command -v "$tool" >/dev/null 2>&1 || { err "$tool required but not found"; exit 1; }
done
```
Harden this pattern for `scripts/preflight.sh` by separating required/optional and accumulating failures before exiting:
```bash
# Pattern: accumulate failures, then exit (from cli/conjure:169-178 + D-04/D-09)
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

**Optional dep pattern** (`install.sh` lines 27-29 / `cli/conjure` lines 170-177):
```bash
# Source: install.sh:27-29
for tool in jq node graphify ast-grep gitleaks; do
  command -v "$tool" >/dev/null 2>&1 && ok "found: $tool" || warn "optional: $tool (see reference/TOOLS-CATALOG.md)"
done
```
Adapt for `scripts/preflight.sh` (separate optional loop, warn-and-continue):
```bash
# Source: cli/conjure:181-185 (power tools loop pattern)
for tool in graphify ast-grep gitleaks repomix; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "  (optional) $tool not installed — see reference/TOOLS-CATALOG.md"
  fi
done
```

**Self-contained path derivation** (required — no CLI state; `cli/conjure` line 24 is the analog for CONJURE_HOME derivation):
```bash
# Source: cli/conjure:24 and scripts/init-project.sh:12
# scripts/preflight.sh must derive its own location; never source CLI variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
```

**Output formatting convention** (`install.sh` lines 15-19 / `audit-setup.sh` lines 14-17):
```bash
# Source: install.sh:15-19 — color helpers (reference only; preflight uses printf directly)
bold() { printf "\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m⚠\033[0m %s\n" "$1"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$1" >&2; }

# Source: audit-setup.sh:14-17 — simpler counter-based helpers
note() { echo "  $1"; }
ok()   { note "✓ $1"; PASS=$((PASS+1)); }
warn() { note "⚠ $1"; WARN=$((WARN+1)); }
err()  { note "✗ $1"; FAIL=$((FAIL+1)); }
```

**Exit code contract** (`install.sh` line 24, `audit-setup.sh` lines 137-139):
```bash
# Source: install.sh:24 — hard exit on required dep missing
exit 1
# Source: audit-setup.sh:137-139 — tiered exit summary
[ "$FAIL" -gt 0 ] && exit 2
[ "$WARN" -gt 0 ] && exit 1
exit 0
```
For `scripts/preflight.sh`: exit 1 on required-dep failure; exit 0 if all required present (optional missing is warn-only). This preserves the `cmd_preflight || return 1` calling pattern in `cli/conjure` line 67.

---

### `cli/conjure` (MOD — controller, request-response)

**Analog:** `cli/conjure` lines 165-167 (stub-delegate pattern), lines 199-209 (dispatch block)

**Stub-delegate pattern** (`cli/conjure` lines 165-167 — `cmd_install_mcp` is the exact model to copy):
```bash
# Source: cli/conjure:165-167
cmd_install_mcp() {
  bash "$CONJURE_HOME/scripts/install-mcp-stack.sh"
}
```
Replace `cmd_preflight()` body (lines 169-188) with this same stub-delegate form:
```bash
# New body for cmd_preflight — replaces lines 169-188
cmd_preflight() {
  bash "$CONJURE_HOME/scripts/preflight.sh"
}
```
The `|| return 1` call in `cmd_init` (line 67) requires no change — it propagates the non-zero exit from `preflight.sh` exactly as before.

**Dispatch block addition** (`cli/conjure` lines 199-209):
```bash
# Source: cli/conjure:199-209 — add preflight case, matching the existing style
case "${1:-help}" in
  init)            shift; cmd_init "$@"            ;;
  migrate)         shift; cmd_migrate "$@"         ;;
  audit)           shift; cmd_audit "$@"           ;;
  update)          shift; cmd_update "$@"          ;;
  refresh-graph)   shift; cmd_refresh_graph "$@"   ;;
  install-mcp)     shift; cmd_install_mcp "$@"     ;;
  preflight)       shift; cmd_preflight "$@"       ;;   # ADD THIS LINE
  version|-v|--version) cmd_version                ;;
  help|-h|--help)  shift; cmd_help "$@"            ;;
  *)               echo "Unknown command: $1"; usage; exit 1 ;;
esac
```

**usage() update** (`cli/conjure` lines 27-47 — add preflight to the help string):
```bash
# Source: cli/conjure:36-42 — usage() subcommand list pattern
Usage:
  conjure init [new|existing|migrate] [--profile=<stack>] [--dry-run] [target]
  conjure preflight                                        # ADD THIS LINE
  conjure audit [target]
  ...
```

---

### `templates/settings.json.tmpl` (MOD — config)

**Analog:** `templates/settings.json.tmpl` lines 41-84 (current hooks block) + `templates/hooks-nodejs/README.md` (target command format)

**Current hook command strings to replace** (`templates/settings.json.tmpl` lines 44-83):
```json
// Source: templates/settings.json.tmpl:44-83 — current (bash, to be replaced)
"command": "bash .claude/hooks/post-edit-format.sh \"$CLAUDE_FILE_PATH\""
"command": "bash .claude/hooks/pre-bash-block-destructive.sh \"$CLAUDE_COMMAND\""
"command": "bash .claude/hooks/stop-compound-engineering.sh"
"command": "bash .claude/hooks/session-start-context.sh"
```

**Target node command format** (`templates/hooks-nodejs/README.md` lines 35-47):
```json
// Source: templates/hooks-nodejs/README.md:35-47 — canonical node command format
{ "type": "command", "command": "node .claude/hooks/post-edit-format.mjs" }
```
Key: no arguments — `.mjs` hooks read `process.env.CLAUDE_FILE_PATH` and `process.env.CLAUDE_COMMAND` directly.

**Full hooks block replacement** (complete target state for the `"hooks"` key in `templates/settings.json.tmpl`):
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
Note: `pre-commit-quality-gate.mjs` is added as a second hook in `PreToolUse[Bash]` — it was absent from the bash template. The `.mjs` hook guards itself with `if (!/^git\s+commit/.test(cmd)) process.exit(0)` so it is safe to wire unconditionally.

---

### `scripts/init-project.sh` (MOD — utility, file-I/O)

**Analog:** `scripts/init-project.sh` lines 46-53 (current `.sh` hook copy loop)

**Current hook copy loop** (`scripts/init-project.sh` lines 45-53):
```bash
# Source: scripts/init-project.sh:45-53 — pattern to replace
# 4. Copy hooks (executable)
for hook in "$KIT"/templates/hooks/*.sh; do
  name=$(basename "$hook")
  if [ ! -f ".claude/hooks/$name" ]; then
    cp "$hook" ".claude/hooks/$name"
    chmod +x ".claude/hooks/$name"
    echo "  ✓ created .claude/hooks/$name"
  fi
done
```

**Target `.mjs` loop** (same structure, new source dir, no chmod):
```bash
# Copy hooks (node .mjs — works on all platforms including Windows)
for hook in "$KIT"/templates/hooks-nodejs/*.mjs; do
  name=$(basename "$hook")
  if [ ! -f ".claude/hooks/$name" ]; then
    cp "$hook" ".claude/hooks/$name"
    # .mjs files invoked via `node` — no chmod +x needed
    echo "  ✓ created .claude/hooks/$name"
  fi
done
```
Key differences: `hooks-nodejs/*.mjs` replaces `hooks/*.sh`; `chmod +x` line is removed (node invokes `.mjs` by filename, not as an executable).

**Idempotency guard** — the `[ ! -f ".claude/hooks/$name" ]` guard is preserved exactly from the current pattern. Do not change it.

---

### `scripts/audit-setup.sh` (MOD — utility, request-response)

**Analog:** `scripts/audit-setup.sh` lines 96-103 (current hook check block)

**Current hook check** (`scripts/audit-setup.sh` lines 96-103):
```bash
# Source: scripts/audit-setup.sh:96-103 — current check (finds .sh, checks chmod +x)
  # Hook scripts executable
  if [ -d .claude/hooks ]; then
    while IFS= read -r hook; do
      if [ -x "$hook" ]; then ok "Hook executable: $(basename "$hook")"
      else err "Hook NOT executable: $(basename "$hook") — run chmod +x"
      fi
    done < <(find .claude/hooks -maxdepth 1 -name '*.sh')
  fi
```

**Target check for `.mjs` hooks** — verify `.mjs` files referenced in `settings.json` exist; drop the `chmod +x` check (irrelevant for node-invoked files):
```bash
  # Hook files present (.mjs — invoked via node, no chmod needed)
  if [ -d .claude/hooks ]; then
    while IFS= read -r hook; do
      if [ -f "$hook" ]; then ok "Hook present: $(basename "$hook")"
      else err "Hook MISSING: $(basename "$hook") — re-run conjure init"
      fi
    done < <(find .claude/hooks -maxdepth 1 -name '*.mjs')
  fi
```
Key: `name '*.sh'` → `name '*.mjs'`; `-x "$hook"` (executable bit) → `-f "$hook"` (file existence); error message updated.

**Reporting helpers** (`scripts/audit-setup.sh` lines 14-17) — unchanged, use existing:
```bash
# Source: scripts/audit-setup.sh:14-17 — use these verbatim
note() { echo "  $1"; }
ok()   { note "✓ $1"; PASS=$((PASS+1)); }
warn() { note "⚠ $1"; WARN=$((WARN+1)); }
err()  { note "✗ $1"; FAIL=$((FAIL+1)); }
```

---

### `tests/run.sh` (MOD — test, request-response)

**Analog:** `tests/run.sh` lines 93-101 (audit self-test section — identical structure for a new section)

**Section header + test body pattern** (`tests/run.sh` lines 95-101):
```bash
# Source: tests/run.sh:95-101 — section header + run + rc check pattern
echo
echo "▸ Audit script self-test (must not crash)"
bash scripts/audit-setup.sh "$CONJURE_HOME" >/dev/null 2>&1
rc=$?
if [ "$rc" -le 2 ]; then pass "audit-setup.sh ran (rc=$rc, expected 0|1|2)"
else fail "audit-setup.sh crashed (rc=$rc)"
fi
```
New preflight section follows this exact pattern (echo section header, run script, check rc).

**pass/fail helpers** (`tests/run.sh` lines 14-15) — unchanged, already defined:
```bash
# Source: tests/run.sh:14-15
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
```

**PATH-manipulation test pattern** (`tests/run.sh` lines 29-33 — process substitution, inline condition):
```bash
# Source: tests/run.sh:29-33 — inline subshell with conditional (adapt for PATH override)
while IFS= read -r script; do
  if [ -x "$script" ]; then pass "exec: $script"
  else fail "NOT executable: $script"
  fi
done < <(find scripts cli migrations profiles compliance templates/hooks -name '*.sh' 2>/dev/null)
```

**Lint assertion pattern** (`tests/run.sh` lines 77-81 — grep-based absence check):
```bash
# Source: tests/run.sh:79-81 — grep-based lint assertion
if grep -rn "^@" templates/CLAUDE.md.tmpl 2>/dev/null; then fail "@imports in CLAUDE.md template"
else pass "no @imports in templates"
fi
```
Adapt for settings.json.tmpl lint assertions:
```bash
# Verify settings.json.tmpl has no bash hooks (SAFE-03)
if grep -q 'bash .claude/hooks/' templates/settings.json.tmpl 2>/dev/null; then
  fail "settings.json.tmpl still contains bash hook commands"
else pass "settings.json.tmpl: no bash hook commands"
fi
# Verify settings.json.tmpl has node hooks (SAFE-03)
if grep -q 'node .claude/hooks/' templates/settings.json.tmpl 2>/dev/null; then
  pass "settings.json.tmpl: node hook commands present"
else fail "settings.json.tmpl: node hook commands MISSING"
fi
```

**Section placement** — insert the new preflight section after the audit self-test block (lines 93-101) and before the migration coverage block (lines 103-110). Follow the blank line + `echo "▸ ..."` separator convention.

---

## Shared Patterns

### Shebang and Error Handling Flags
**Source:** All scripts in `scripts/` (e.g., `scripts/audit-setup.sh` line 1, 8; `scripts/install-mcp-stack.sh` lines 1, 8)
**Apply to:** `scripts/preflight.sh`
```bash
#!/usr/bin/env bash
set -uo pipefail
```
Do NOT use `set -euo pipefail` in any script that uses `command -v` as a probe (pitfall documented in RESEARCH.md). The new `scripts/preflight.sh` must use `-uo pipefail` only.

### Self-Contained Path Derivation
**Source:** `scripts/init-project.sh` line 12; `cli/conjure` line 24; `tests/run.sh` line 6
**Apply to:** `scripts/preflight.sh` (must not import CLI state)
```bash
# tests/run.sh:6
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# scripts/init-project.sh:12
KIT="$(cd "$(dirname "$0")/.." && pwd)"
# cli/conjure:24
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
```
`scripts/preflight.sh` must use `$(dirname "$0")` for any path it needs. No `$CONJURE_HOME` sourced from caller.

### command -v Dep Check
**Source:** `install.sh` lines 23-24; `install-mcp-stack.sh` lines 15-19; `cli/conjure` lines 171-173
**Apply to:** `scripts/preflight.sh`
```bash
# install.sh:23-24 — hard exit variant
command -v "$tool" >/dev/null 2>&1 || { err "$tool required but not found"; exit 1; }

# install-mcp-stack.sh:16-19 — soft check variant
if ! command -v "$tool" >/dev/null 2>&1; then
  echo "✗ $tool not found — install Node.js first (https://nodejs.org)"
  exit 1
fi
```
Always use `>/dev/null 2>&1` to suppress output; check the return code explicitly via `if !` or `||`.

### Idempotency Guard in File Copy
**Source:** `scripts/init-project.sh` lines 28-34 (core templates), lines 46-53 (hooks)
**Apply to:** `scripts/init-project.sh` hook copy block (preserve the guard when replacing `.sh` with `.mjs`)
```bash
if [ ! -f ".claude/hooks/$name" ]; then
  cp "$hook" ".claude/hooks/$name"
  echo "  ✓ created .claude/hooks/$name"
fi
```

### Pass/Fail Counter Pattern
**Source:** `tests/run.sh` lines 9-10, 14-15; `scripts/audit-setup.sh` lines 11-17
**Apply to:** `tests/run.sh` (new section reuses existing counters — no new counters needed)
```bash
# tests/run.sh — counters already defined at top; section just calls pass()/fail()
PASS=0
FAIL=0
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
```

---

## No Analog Found

All 6 files have analogs in the codebase. No file requires falling back to RESEARCH.md patterns exclusively.

The OS detection function (`_detect_os`) in `scripts/preflight.sh` has no exact analog — `install.sh` does two-bucket dep checks (required vs optional) but has no OS branching. Use the locked pattern from CONTEXT.md D-11 and RESEARCH.md "Complete OS Detection Function" section for this function only.

---

## Metadata

**Analog search scope:** `cli/`, `scripts/`, `tests/`, `templates/`, `install.sh`
**Files scanned:** 8 (cli/conjure, scripts/audit-setup.sh, scripts/init-project.sh, scripts/install-mcp-stack.sh, install.sh, tests/run.sh, templates/settings.json.tmpl, templates/hooks-nodejs/README.md)
**Pattern extraction date:** 2026-05-24
