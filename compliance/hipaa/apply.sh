#!/usr/bin/env bash
set -uo pipefail
TARGET="${1:-$(pwd)}"
PROFILE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$CONJURE_HOME/lib/mutate.sh"

echo "▸ Applying compliance overlay: HIPAA → $TARGET"

if [ -f "$TARGET/CLAUDE.md" ] && [ -f "$PROFILE_DIR/CLAUDE.md.fragment" ]; then
  if ! grep -q "<!-- compliance:hipaa -->" "$TARGET/CLAUDE.md"; then
    mutate_write "$TARGET/CLAUDE.md" "$(cat "$PROFILE_DIR/CLAUDE.md.fragment")" "--append"
    echo "  ✓ appended HIPAA fragment to CLAUDE.md"
  fi
fi

# Hook: pre-commit PHI scan
mutate_mkdir "$TARGET/.claude/hooks"
mutate_cp "$PROFILE_DIR/pre-commit-phi-scan.sh" "$TARGET/.claude/hooks/pre-commit-phi-scan.sh"
[ "${DRY_RUN:-0}" = "1" ] || chmod +x "$TARGET/.claude/hooks/pre-commit-phi-scan.sh" 2>/dev/null

# Add controls checklist
mutate_mkdir "$TARGET/docs/compliance"
mutate_cp "$PROFILE_DIR/CONTROLS.md" "$TARGET/docs/compliance/HIPAA-CONTROLS.md"

mutate_summary
echo "✓ HIPAA overlay applied"
echo "  ⚠ Compliance ≠ Config. Engage your compliance officer."
