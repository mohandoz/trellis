#!/usr/bin/env bash
# gates/decision-scan.sh — D-11 archive guard: decision-vocabulary scan.
# Usage: bash decision-scan.sh <archive-candidate-file>
# Output (stdout): "individual" if the candidate carries decision vocabulary
#                  (escalate to per-file confirmation); "bulk" otherwise.
# Exit codes: 0 = scan succeeded (read the stdout token), 2 = unreadable input.
#   This helper NEVER exits 1; the routing signal is the stdout token, not the
#   exit code. Read-only: writes no files.
#
# The 5 D-11 terms (case-insensitive): decided / we chose / rationale / do not /
# never. Scope is the single candidate passed in (never a full-tree grep). Matching
# lines are echoed to stderr so the skill can show the user WHY a file escalated.
# Over-flagging is the SAFE direction — an individual confirm never loses a
# decision; a bulk-archive would (CR-6 HIGH). Do NOT relax below the 5 terms.

set -uo pipefail

candidate="${1:-}"
if [ -z "$candidate" ]; then
  echo "✗ decision-scan: usage: decision-scan.sh <archive-candidate-file>" >&2
  exit 2
fi
if [ ! -r "$candidate" ]; then
  echo "✗ decision-scan: cannot read candidate file: $candidate" >&2
  exit 2
fi

# grep -E for the multi-word terms; word-boundary (\b) on the bare-word terms
# (`never`, `do not`) trims noise per Pitfall 5 without dropping below the 5 terms.
matches="$(grep -niE 'decided|we chose|rationale|\bdo not\b|\bnever\b' "$candidate" || true)"

if [ -n "$matches" ]; then
  printf '%s\n' "$matches" >&2
  echo "individual"
else
  echo "bulk"
fi

exit 0
