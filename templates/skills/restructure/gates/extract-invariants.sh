#!/usr/bin/env bash
# gates/extract-invariants.sh — D-06 constraint-extraction pre-pass.
# Usage: bash extract-invariants.sh <source-claude.md> [state-dir]
# Writes: <out-dir>/INVARIANTS.candidates  (out-dir = a .conjure-adopt-state dir).
# Exit codes: 0 = success (candidates file written, possibly empty on a
#             constraint-free source), 2 = unreadable source / un-writable or
#             unsafe state dir. NEVER exits 1.
#
# Greps canonical-token signal lines (must/never/always/forbidden/required/do not/
# exit 2/@import/≤N/N lines/`backtick-tokens`) from the SOURCE CLAUDE.md, one per
# line. The OUTPUT is CANDIDATES, not the final INVARIANTS.txt: the LLM (Read)
# later refines these into the confirmed .conjure-adopt-state/INVARIANTS.txt that
# verify-invariants.sh checks (D-05). This grep is the deterministic checklist the
# LLM must cover.
#
# CHOKEPOINT (T-23-08 / Security V12): this helper writes ONLY under a
# `.conjure-adopt-state` directory. If [state-dir] does not already contain a
# `.conjure-adopt-state` path component, one is appended; any `..` traversal in
# [state-dir] is refused (exit 2) so a write can never escape the adopt-state root.

set -uo pipefail

SRC_CLAUDE="${1:-}"
STATE_DIR="${2:-.conjure-adopt-state}"

if [ -z "$SRC_CLAUDE" ]; then
  echo "✗ extract-invariants: usage: extract-invariants.sh <source-claude.md> [state-dir]" >&2
  exit 2
fi
if [ ! -r "$SRC_CLAUDE" ]; then
  echo "✗ extract-invariants: cannot read source CLAUDE.md: $SRC_CLAUDE" >&2
  exit 2
fi

# Refuse path traversal in the requested state dir (defense in depth, T-23-08).
case "/$STATE_DIR/" in
  */../*)
    echo "✗ extract-invariants: state-dir '$STATE_DIR' contains '..' traversal (refused)" >&2
    exit 2
    ;;
esac

# Resolve the output dir: it MUST be a .conjure-adopt-state dir. If the requested
# state-dir already names one (as a component), use it as-is; otherwise nest one
# inside it. This honors the chokepoint regardless of how the caller passes the dir.
case "/$STATE_DIR/" in
  */.conjure-adopt-state/*|*/.conjure-adopt-state)
    OUT_DIR="$STATE_DIR"
    ;;
  *)
    OUT_DIR="$STATE_DIR/.conjure-adopt-state"
    ;;
esac

# Final containment assertion: the resolved out-dir MUST contain .conjure-adopt-state.
case "/$OUT_DIR/" in
  */.conjure-adopt-state/*) ;;
  *)
    echo "✗ extract-invariants: refusing to write outside .conjure-adopt-state ($OUT_DIR)" >&2
    exit 2
    ;;
esac

if ! mkdir -p "$OUT_DIR" 2>/dev/null; then
  echo "✗ extract-invariants: cannot create state dir: $OUT_DIR" >&2
  exit 2
fi

CANDIDATES="$OUT_DIR/INVARIANTS.candidates"

# Scope the grep to the single source file (full-tree grep is slow — PITFALLS).
# `|| true` keeps a constraint-free source a success (empty candidates, exit 0).
grep -niE 'must|never|always|forbidden|required|do not|exit 2|@import|≤[0-9]+|[0-9]+ lines|`[^`]+`' \
  "$SRC_CLAUDE" > "$CANDIDATES" 2>/dev/null || true

if [ ! -f "$CANDIDATES" ]; then
  echo "✗ extract-invariants: failed to write candidates: $CANDIDATES" >&2
  exit 2
fi

exit 0
