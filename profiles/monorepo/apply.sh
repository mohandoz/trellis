#!/usr/bin/env bash
# monorepo profile — adds nested CLAUDE.md scaffolds per package.
set -uo pipefail
TARGET="${1:-$(pwd)}"
PROFILE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$CONJURE_HOME/lib/mutate.sh"

echo "▸ Applying profile: monorepo → $TARGET"

# Detect package directories
DETECTED=()
[ -d "$TARGET/packages" ] && DETECTED+=("packages")
[ -d "$TARGET/apps" ] && DETECTED+=("apps")
[ -d "$TARGET/services" ] && DETECTED+=("services")
[ -d "$TARGET/libs" ] && DETECTED+=("libs")

if [ ${#DETECTED[@]} -eq 0 ]; then
  echo "  ⚠ no monorepo dirs detected (packages/, apps/, services/, libs/)"
  exit 1
fi

for dir in "${DETECTED[@]}"; do
  for pkg in "$TARGET/$dir"/*; do
    [ -d "$pkg" ] || continue
    name=$(basename "$pkg")

    if [ ! -f "$pkg/CLAUDE.md" ]; then
      MONOREPO_CONTENT="# $dir/$name — Local Working Notes

<!-- This nested CLAUDE.md loads automatically when Claude reads files here. -->
<!-- ≤50 lines. Override root rules ONLY where this package differs. -->

## Local rules

- <package-specific rule>

## Build/test (this package only)

| Goal | Command |
| --- | --- |
| Build | \`<cmd>\` |
| Test | \`<cmd>\` |

## Notes

- Owner: <name>
- Type: <library | service | app>"
      mutate_write "$pkg/CLAUDE.md" "$MONOREPO_CONTENT"
      echo "  ✓ scaffolded $dir/$name/CLAUDE.md"
    else
      echo "  • $dir/$name/CLAUDE.md exists — skipping"
    fi
  done
done

# Append monorepo fragment to root CLAUDE.md
if [ -f "$TARGET/CLAUDE.md" ] && [ -f "$PROFILE_DIR/CLAUDE.md.fragment" ]; then
  if ! grep -q "<!-- profile:monorepo -->" "$TARGET/CLAUDE.md"; then
    mutate_write "$TARGET/CLAUDE.md" "$(cat "$PROFILE_DIR/CLAUDE.md.fragment")" "--append"
    echo "  ✓ appended monorepo fragment to root CLAUDE.md"
  fi
fi

mutate_summary
echo "✓ Profile monorepo applied"
