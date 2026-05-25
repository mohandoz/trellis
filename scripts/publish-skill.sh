#!/usr/bin/env bash
# publish-skill.sh — Worker script for conjure publish-skill.
# Validates a project skill (frontmatter, size cap, SHA-pinning, egress scan),
# then prints the gh pr create command (or manual URL + checklist) for the user to run.
#
# Usage:
#   bash scripts/publish-skill.sh <skill-name> [--to <org/repo>] [--dry-run]
#   TARGET_REPO=org/repo DRY_RUN=1 bash scripts/publish-skill.sh my-skill
#
# Exit codes:
#   0 = success
#   1 = validation error (user-fixable: frontmatter, size, egress, SHA-pinning)
#   2 = hard prerequisite failure (missing dep, missing SKILL.md)

set -euo pipefail

CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
source "$CONJURE_HOME/lib/mutate.sh"

# Env defaults — both env var and flag paths work
DRY_RUN="${DRY_RUN:-0}"
TARGET_REPO="${TARGET_REPO:-mohandoz/conjure}"

SKILL_NAME="${1:-}"
shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    --to)       shift; TARGET_REPO="${1:-}" ;;
    --to=*)     TARGET_REPO="${1#--to=}" ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: conjure publish-skill <name> [--to <org/repo>] [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

[ -z "$SKILL_NAME" ] && { echo "Usage: conjure publish-skill <name> [--to <org/repo>] [--dry-run]" >&2; exit 1; }

if ! printf '%s' "$TARGET_REPO" | grep -qE '^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$'; then
  echo "Invalid --to format: use owner/repo" >&2
  exit 1
fi

# Prerequisite checks — exit 2 for missing deps
if ! command -v git >/dev/null 2>&1; then
  echo "✗ git not installed" >&2
  exit 2
fi

SKILL_FILE="$(pwd)/.claude/skills/$SKILL_NAME/SKILL.md"
if [ ! -f "$SKILL_FILE" ]; then
  echo "✗ Skill not found: $SKILL_FILE" >&2
  exit 2
fi

TARGET="$(pwd)"

# SHA-pinning guards — exit 1 each, per D-07/D-08
PORCELAIN="$(git -C "$TARGET" status --porcelain ".claude/skills/$SKILL_NAME/" 2>/dev/null)"
if [ -n "$PORCELAIN" ]; then
  echo "✗ Skill has uncommitted changes. Commit first:" >&2
  echo "    git add .claude/skills/$SKILL_NAME/ && git commit" >&2
  exit 1
fi

CONJURE_VERSION="$(cat "$CONJURE_HOME/VERSION" 2>/dev/null || echo unknown)"
if ! git -C "$CONJURE_HOME" describe --exact-match HEAD >/dev/null 2>&1; then
  echo "✗ Conjure version $CONJURE_VERSION is not a tagged release." >&2
  echo "  Run from a tagged commit." >&2
  exit 1
fi

# Frontmatter validation — exit 1
FM_BLOCK="$(sed -n '1,/^---$/p' "$SKILL_FILE" | grep -v '^---$')"

SKILL_NAME_FM="$(printf '%s\n' "$FM_BLOCK" | grep '^name:' | head -1 | sed 's/^name: *//' | tr -d '"')"
SKILL_DESC="$(printf '%s\n' "$FM_BLOCK" | grep '^description:' | head -1 | sed 's/^description: *//' | tr -d '"')"

[ -z "$SKILL_NAME_FM" ] && { echo "✗ SKILL.md missing 'name:' frontmatter field" >&2; exit 1; }
if ! printf '%s' "$SKILL_NAME_FM" | grep -qE '^[a-z][a-z0-9-]{1,40}$'; then
  echo "✗ name '$SKILL_NAME_FM' does not match ^[a-z][a-z0-9-]{1,40}$" >&2
  exit 1
fi
[ "$SKILL_NAME_FM" != "$SKILL_NAME" ] && {
  echo "✗ Frontmatter name '$SKILL_NAME_FM' does not match directory name '$SKILL_NAME'" >&2
  exit 1
}
[ -z "$SKILL_DESC" ] && { echo "✗ SKILL.md missing 'description:' frontmatter field" >&2; exit 1; }
DESC_LEN="$(printf '%s' "$SKILL_DESC" | wc -c | tr -d ' ')"
[ "$DESC_LEN" -lt 30 ] && { echo "✗ description too short ($DESC_LEN chars, min 30)" >&2; exit 1; }
[ "$DESC_LEN" -gt 400 ] && { echo "✗ description too long ($DESC_LEN chars, max 400)" >&2; exit 1; }

LINES="$(wc -l < "$SKILL_FILE" | tr -d ' ')"
if [ "$LINES" -gt 200 ]; then
  echo "✗ Skill exceeds 200-line cap ($LINES lines). Trim before publishing." >&2
  exit 1
fi

# Egress scan — body only, exit 1 per D-01/D-02
BODY="$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_FILE")"

EGRESS_HIT=0
if HITS="$(printf '%s\n' "$BODY" | grep -nE 'curl|wget|\bnc\b|fetch|http://|https://' 2>/dev/null)"; then
  if [ -n "$HITS" ]; then
    echo "✗ Egress scan: network patterns found:" >&2
    printf '%s\n' "$HITS" >&2
    EGRESS_HIT=1
  fi
fi
if HITS="$(printf '%s\n' "$BODY" | grep -nE '\$(HOME|USER|SECRET|API_KEY|TOKEN|PASSWORD)' 2>/dev/null)"; then
  if [ -n "$HITS" ]; then
    echo "✗ Egress scan: sensitive env var refs found:" >&2
    printf '%s\n' "$HITS" >&2
    EGRESS_HIT=1
  fi
fi
[ "$EGRESS_HIT" -eq 1 ] && exit 1

# PR instruction printing — per D-03/D-04/D-05
echo "▸ conjure publish-skill: validation passed."
echo ""
if command -v gh >/dev/null 2>&1; then
  echo "Run this command to open the PR:"
  echo ""
  echo "  gh pr create \\"
  echo "    --repo $TARGET_REPO \\"
  echo "    --title \"feat(skills): add ${SKILL_NAME} skill\" \\"
  echo "    --body \"Contributes \`${SKILL_NAME}\` skill from \$(git -C '$TARGET' rev-parse --short HEAD)\" \\"
  echo "    --head \$(git -C '$TARGET' branch --show-current)"
else
  echo "gh not found — open PR manually:"
  echo ""
  echo "  1. Push your branch:  git push -u origin \$(git -C '$TARGET' branch --show-current)"
  echo "  2. Visit: https://github.com/$TARGET_REPO/compare"
  echo "  3. Create a PR titled: feat(skills): add ${SKILL_NAME} skill"
  echo "  4. Skill file: .claude/skills/$SKILL_NAME/SKILL.md"
fi

mutate_summary
exit 0
