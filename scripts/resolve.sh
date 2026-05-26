#!/usr/bin/env bash
# scripts/resolve.sh — interactive sidecar walker for `conjure resolve`.
# Walks each .conjure-conflict-* sidecar left by `conjure update --apply`,
# prompts [k]eep / [a]pply / [e]dit / [s]kip per file, and uses mutate_rm
# for dry-run-safe sidecar removal.
# Usage: [CONJURE_HOME=<path>] [DRY_RUN=1] bash resolve.sh [target]
# Exit codes: 0 = all sidecars resolved (or none existed), 2 = hard failure

set -uo pipefail

CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${1:-$(pwd)}"

# Step 1: Source lib/mutate.sh (mutate_rm, mutate_write, mutate_summary).
# SC1090: dynamic path — shellcheck can't follow, suppress with directive.
# shellcheck source=/dev/null
source "$CONJURE_HOME/lib/mutate.sh" || { echo "resolve.sh: cannot source lib/mutate.sh" >&2; exit 2; }

# Step 2: Sidecar discovery — find all .conjure-conflict-* files into a sorted tmpfile.
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

find "$TARGET" -name '.conjure-conflict-*' -type f > "$tmpfile" 2>/dev/null || true
sort "$tmpfile" -o "$tmpfile"

# Step 3: All-clear check — exit 0 WITHOUT requiring a TTY (per RESOLVE-02).
if [ ! -s "$tmpfile" ]; then
  echo "No conflicts remain"
  exit 0
fi

# Step 4: Non-interactive guard — fires only when sidecars ARE present (per RESOLVE-01).
# CONJURE_FORCE_INTERACTIVE=1 is a test-only escape hatch that bypasses this guard.
if ! { [ -t 0 ] || [ "${CONJURE_FORCE_INTERACTIVE:-0}" = "1" ]; }; then
  echo "conjure resolve: stdin is not a TTY — interactive mode required" >&2
  exit 2
fi

# Step 5: Main prompt loop — process each sidecar interactively.
# Open tmpfile on fd 3 so that the inner `read -r -p` can still read from stdin (fd 0).
exec 3< "$tmpfile"
while IFS= read -r sidecar_path <&3; do
  sidecar_name="$(basename "$sidecar_path")"
  encoded="${sidecar_name#.conjure-conflict-}"
  rel="$(printf '%s' "$encoded" | tr '_' '/')"
  current_file="$TARGET/$rel"

  echo ""
  echo "Sidecar: $sidecar_name"
  echo "  Current file: $rel"

  while true; do
    read -r -p "  [k]eep / [a]pply / [e]dit / [s]kip: " choice
    case "$choice" in
      k|keep)
        mutate_rm "$sidecar_path"
        echo "  kept (sidecar removed)"
        break
        ;;
      a|apply)
        content="$(cat "$sidecar_path")"
        mutate_write "$current_file" "$content"
        mutate_rm "$sidecar_path"
        echo "  applied (sidecar removed)"
        break
        ;;
      e|edit)
        "${EDITOR:-vi}" "$sidecar_path"
        # No break — re-prompt after editor exits
        ;;
      s|skip)
        echo "  skipped"
        break
        ;;
      *)
        echo "  Unknown choice; please enter k, a, e, or s"
        # No break — re-prompt
        ;;
    esac
  done
done
exec 3<&-

# After loop: recount remaining sidecars.
remaining="$(find "$TARGET" -name '.conjure-conflict-*' -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$remaining" -eq 0 ]; then
  echo "No conflicts remain"
fi

mutate_summary
