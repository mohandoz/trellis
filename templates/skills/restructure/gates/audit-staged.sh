#!/usr/bin/env bash
# gates/audit-staged.sh — GATE B: single-file @import / cap-breach audit shim.
# Usage: CONJURE_HOME=<kit-root> bash audit-staged.sh <staging-file>
# Exit codes: 0 = clean, 2 = @import OR cap breach (BLOCK) / bad args. NEVER exits 1.
# Runs BEFORE any human approval (D-13/D-14).
#
# The proposed file is staged as CLAUDE.md in a throwaway temp dir and run through
# the REAL `conjure audit` (audit-setup.sh) so the human sees WHY it blocked
# (RESTR-05 / criterion 5). The BLOCK decision keys on two NAMED deterministic
# conditions, NOT the audit return code: conjure audit returns rc=1 for unrelated
# harness-completeness WARNs even on a clean CLAUDE.md, so keying on rc>=1 would
# block every clean proposal. The two conditions are exactly RESTR-05's:
#   (1) an `@import` line (^@) — always a hard foot-gun;
#   (2) line count > CLAUDE_MD_CAP (100) — cap breach for a proposed CLAUDE.md.
# The audit shim provides the human-readable WHY; the grep/line-count provides the
# satisfiable block decision and stands alone as the fallback if the shim is absent.

set -uo pipefail

# CONJURE_HOME must point at the KIT (where scripts/audit-setup.sh + lib/caps.sh live).
# From a TARGET repo's .claude/skills/restructure/gates/, the kit is NOT a relative
# hop away, so the skill exports CONJURE_HOME. Default to a best-effort kit-relative
# resolution (gates/ -> restructure/ -> skills/ -> .claude|templates/skills -> root).
CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"

staged="${1:-}"
if [ -z "$staged" ]; then
  echo "✗ audit-staged: usage: audit-staged.sh <staging-file>" >&2
  exit 2
fi
if [ ! -r "$staged" ]; then
  echo "✗ audit-staged: cannot read staging file: $staged" >&2
  exit 2
fi

# Source caps for CLAUDE_MD_CAP (default 100) — single source of truth (lib/caps.sh).
if [ -r "$CONJURE_HOME/lib/caps.sh" ]; then
  # shellcheck source=/dev/null
  source "$CONJURE_HOME/lib/caps.sh"
fi
CAP="${CLAUDE_MD_CAP:-100}"

# Run the real audit to SURFACE human-readable output (informational only — does
# NOT drive the block decision). Skip silently if the shim is infeasible at runtime.
AUDIT_SCRIPT="$CONJURE_HOME/scripts/audit-setup.sh"
audit_out=""
if [ -f "$AUDIT_SCRIPT" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cp "$staged" "$tmp/CLAUDE.md"
  mkdir -p "$tmp/.claude"           # audit-setup.sh:48 exits 2 without .claude/
  audit_out="$(bash "$AUDIT_SCRIPT" "$tmp" 2>&1)" || true
fi

# Condition 1 — @import (always a hard error).
if grep -q '^@' "$staged"; then
  [ -n "$audit_out" ] && printf '%s\n' "$audit_out" >&2
  echo "✗ restructure: proposed CLAUDE.md contains @import (forbidden eager-load)" >&2
  exit 2
fi

# Condition 2 — cap breach (line count > CLAUDE_MD_CAP). grep -c '' counts lines
# robustly (including a final line without a trailing newline).
lines="$(grep -c '' "$staged")"
if [ "$lines" -gt "$CAP" ]; then
  [ -n "$audit_out" ] && printf '%s\n' "$audit_out" >&2
  echo "✗ restructure: proposed CLAUDE.md is $lines lines (> $CAP cap)" >&2
  exit 2
fi

# Clean. The surfaced WARN-band audit output (if any) is informational and MUST NOT block.
exit 0
