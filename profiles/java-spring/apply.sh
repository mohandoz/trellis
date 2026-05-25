#!/usr/bin/env bash
# profiles/java-spring/apply.sh — overlay for Java 17 + Spring Boot + Gradle.
set -uo pipefail
TARGET="${1:-$(pwd)}"

PROFILE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$CONJURE_HOME/lib/mutate.sh"

echo "▸ Applying profile: java-spring → $TARGET"

# Append CLAUDE.md fragment
if [ -f "$TARGET/CLAUDE.md" ] && [ -f "$PROFILE_DIR/CLAUDE.md.fragment" ]; then
  if ! grep -q "<!-- profile:java-spring -->" "$TARGET/CLAUDE.md"; then
    mutate_write "$TARGET/CLAUDE.md" "$(cat "$PROFILE_DIR/CLAUDE.md.fragment")" "--append"
    echo "  ✓ appended CLAUDE.md fragment"
  fi
fi

# Override post-edit-format hook for Java
if [ -d "$TARGET/.claude/hooks" ] && [ -f "$PROFILE_DIR/hooks/post-edit-format.sh" ]; then
  mutate_cp "$PROFILE_DIR/hooks/post-edit-format.sh" "$TARGET/.claude/hooks/post-edit-format.sh"
  [ "${DRY_RUN:-0}" = "1" ] || chmod +x "$TARGET/.claude/hooks/post-edit-format.sh"
  echo "  ✓ installed Java-aware format hook"
fi

# Pre-flight
"$PROFILE_DIR/preflight.sh" || echo "  ⚠ preflight had warnings; continuing"

mutate_summary
echo "✓ Profile java-spring applied"
