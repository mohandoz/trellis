# Phase 11: Skill Publishing - Research

**Researched:** 2026-05-25
**Domain:** POSIX bash CLI — `conjure publish-skill` command, static egress scanning, SHA-pinning, PR-flow printing
**Confidence:** HIGH (all key files read directly from the repo this session)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Egress Scan (SKILL-01)**
- D-01: Scan scope covers three categories in the SKILL.md body: shell exfil tool patterns (`curl`, `wget`, `nc`, `fetch`), hard-coded URL patterns (`http://`, `https://`), and sensitive env var refs (`$HOME`, `$USER`, `$SECRET` and common variants)
- D-02: Any egress scan hit is a hard block — exit 1 and print which lines matched. User must remove the pattern before the skill can be submitted. No warn-and-continue option.

**PR Submission Flow (SKILL-02, SKILL-04)**
- D-03: When `gh` is present: `conjure publish-skill` validates + stages the skill content, then **prints** the exact `gh pr create` command for the user to run. Does NOT execute `gh pr create` itself.
- D-04: When `gh` is absent: print the manual PR URL for `mohandoz/conjure` (or the `--to` target) plus a step-by-step checklist. Matches Phase 10's fallback pattern.
- D-05: `--to <org/repo>` uses the same staged + print flow, just substitutes the target repo in the printed `gh pr create` command. No extra automation.
- D-06: What gets submitted (SKILL.md vs. SKILL.md + plugin.json stub) is left to researcher/planner to determine.

**SHA-Pinning (SKILL-03)**
- D-07: Two guards run before any submission step:
  1. Skill clean check: `git status --porcelain .claude/skills/<name>/` must be empty. Failure message: `"Skill has uncommitted changes. Commit first: git add .claude/skills/<name>/ && git commit"`
  2. Conjure version tag check: `git describe --exact-match HEAD 2>/dev/null` must succeed. Failure message: `"Conjure version <X> is not a tagged release. Run from a tagged commit."`
- D-08: Both checks exit 1 with specific per-failure messages (not a combined generic message).

### Claude's Discretion
- Exact content of the plugin.json stub (if any) — researcher determines from `mohandoz/conjure` contribution conventions
- Function naming inside `scripts/publish-skill.sh`
- Exact PR body/title template for the printed `gh pr create` command
- Whether to update `.conjure-version` or any audit trail after successful staging

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SKILL-01 | User can run `conjure publish-skill <name>` to validate a project skill against frontmatter schema, size cap (≤200 lines), and a static egress scan before submitting | Frontmatter validation: `grep`-based on SKILL.md frontmatter block (no jq YAML support needed — schema is simple key: value pairs). Schema in `.claude-plugin/SCHEMAS/skill.schema.json` defines required fields, patterns, and constraints. Size cap: `wc -l`. Egress scan: `grep -nE`. |
| SKILL-02 | `conjure publish-skill` opens a pull request against the public kit via `gh pr create`; if `gh` is absent, prints the manual PR URL and checklist instead | Pattern is direct from Phase 10: `command -v gh` → print command or print URL+checklist. No execution of `gh`. |
| SKILL-03 | Published skill commit is SHA-pinned; branch-HEAD references are rejected with an error | Two git checks: `git status --porcelain` (dirty skill tree) and `git describe --exact-match HEAD` (non-tagged conjure HEAD). Both exit 1 with distinct messages. |
| SKILL-04 | User can run `conjure publish-skill <name> --to <org/repo>` to contribute to a private kit or org overlay repo | `--to` is a simple flag that replaces `mohandoz/conjure` in the printed `gh pr create` command. Same flow otherwise. |
</phase_requirements>

---

## Summary

Phase 11 adds `conjure publish-skill <name>` — a command that validates a project skill through three gates (frontmatter + size, egress scan, SHA-pinning), then prints either a `gh pr create` command or a manual URL checklist for the user to run. No PR is auto-fired.

The implementation follows exactly the same structural template as `scripts/publish-plugin.sh` (Phase 10): source `lib/mutate.sh`, parse flags, run prerequisite checks, run validation checks, then emit instructions. The two new concepts unique to this phase are (1) static egress scanning via `grep -nE` and (2) frontmatter schema validation via a bash parsing function (not `jq` — SKILL.md frontmatter is YAML, not JSON).

The planner should expect three deliverables: `scripts/publish-skill.sh` (new worker), `cmd_publish_skill` + dispatch case in `cli/conjure` (modified), and a `SKILL-NN` test block in `tests/run.sh` (modified). The CI shellcheck glob already covers `scripts/*.sh` via `find cli scripts migrations profiles compliance templates/hooks tests lib -name '*.sh'` — no CI change needed for shellcheck. No new external dependencies are introduced.

**Primary recommendation:** Copy `scripts/publish-plugin.sh` as the skeleton for `scripts/publish-skill.sh`; replace the JSON-mutation logic with bash frontmatter parsing + egress grep; the dispatch pattern in `cli/conjure` is verbatim identical to `cmd_publish`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Frontmatter validation | Worker script (publish-skill.sh) | — | Validation logic belongs in the worker, not the CLI dispatcher |
| Egress scanning | Worker script (publish-skill.sh) | — | Static grep; self-contained; same tier as other validation gates |
| SHA-pinning guards | Worker script (publish-skill.sh) | — | Git checks are part of the validation pipeline |
| Flag parsing / dispatch | cli/conjure cmd_publish_skill | — | All dispatchers live in cli/conjure per established pattern |
| PR instruction printing | Worker script (publish-skill.sh) | — | Output is part of the worker's success path, not CLI dispatch |
| Regression tests | tests/run.sh | — | All tests inline in the single test entrypoint per convention |
| CI shellcheck | .github/workflows/ci.yml | — | Already covers scripts/*.sh; no change needed |

---

## Standard Stack

### Core (no new packages)

| Tool | Source | Purpose | Why Standard |
|------|--------|---------|--------------|
| bash (POSIX) | System | Script language | CLAUDE.md hard constraint: no heavy runtime deps |
| jq | apt / brew (already a preflight dep) | JSON emission for plugin.json stub (if included) | Already verified present by preflight |
| git | System (already a preflight dep) | `git status --porcelain`, `git describe --exact-match HEAD` | Already a preflight dep |

**No new npm, pip, or brew dependencies.** [VERIFIED: codebase grep — `package.json` is absent, `dependencies: {}` is the stated constraint]

### Reusable In-Repo Assets

| Asset | Path | Reuse Scope |
|-------|------|-------------|
| mutate.sh | `lib/mutate.sh` | Source for `DRY_RUN`-aware writes; `mutate_write`, `mutate_summary` |
| publish-plugin.sh | `scripts/publish-plugin.sh` | Structural skeleton: arg-parsing, prereq checks, exit code conventions, env pattern |
| skill.schema.json | `.claude-plugin/SCHEMAS/skill.schema.json` | Defines required fields, patterns, constraints to validate against |
| cmd_publish | `cli/conjure` lines 264-278 | Identical dispatch pattern for `cmd_publish_skill` |
| MKTPL sandbox pattern | `tests/run.sh` lines 762-888 | Template for sandbox-based regression test |

---

## Package Legitimacy Audit

> Phase installs no new external packages. All tools (`bash`, `jq`, `git`) are pre-existing preflight dependencies.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
conjure publish-skill <name> [--to <org/repo>] [--dry-run]
         │
         ▼
cli/conjure cmd_publish_skill()          (~15 lines)
  parse: SKILL_NAME, TARGET_REPO, DRY_RUN
  export env vars
  exec: bash scripts/publish-skill.sh
         │
         ▼
scripts/publish-skill.sh
  ┌─────────────────────────────────────────────────┐
  │ GATE 1: Prerequisites                           │
  │   jq installed?  (exit 2 if not)               │
  │   git installed? (exit 2 if not)               │
  │   .claude/skills/<name>/SKILL.md exists?        │
  │   (exit 2 if not)                              │
  └─────────────────────┬───────────────────────────┘
                        │ pass
  ┌─────────────────────▼───────────────────────────┐
  │ GATE 2: SHA-pinning (D-07, D-08)               │
  │   git status --porcelain .claude/skills/<name>/  │
  │   → non-empty → exit 1 (per-failure message)   │
  │   git describe --exact-match HEAD               │
  │   → fails → exit 1 (per-failure message)        │
  └─────────────────────┬───────────────────────────┘
                        │ pass
  ┌─────────────────────▼───────────────────────────┐
  │ GATE 3: Frontmatter + Size validation           │
  │   parse YAML frontmatter from SKILL.md          │
  │   validate: name present, pattern ^[a-z][a-z0-9-]{1,40}$
  │   validate: description ≥30 chars, ≤400 chars   │
  │   validate: name matches directory name         │
  │   wc -l SKILL.md ≤ 200 (exit 1 if over)       │
  └─────────────────────┬───────────────────────────┘
                        │ pass
  ┌─────────────────────▼───────────────────────────┐
  │ GATE 4: Egress scan (D-01, D-02)               │
  │   grep -nE 'curl|wget|nc |fetch|http://|https://' │
  │   grep -nE '\$(HOME|USER|SECRET[^=]*)' body    │
  │   → any hit → print matching lines → exit 1    │
  └─────────────────────┬───────────────────────────┘
                        │ pass (all gates clear)
  ┌─────────────────────▼───────────────────────────┐
  │ EMIT: PR instructions                           │
  │   command -v gh → present:                      │
  │     print "gh pr create" command (don't exec)   │
  │   gh absent:                                    │
  │     print manual PR URL + step-by-step checklist│
  │   --to <org/repo> swaps target repo in command  │
  └─────────────────────────────────────────────────┘
         │
         ▼
  mutate_summary (DRY_RUN accounting)
  exit 0
```

### Recommended Project Structure

```
scripts/
└── publish-skill.sh    # new worker (SKILL-01, SKILL-02, SKILL-03, SKILL-04)

cli/
└── conjure             # modified: add cmd_publish_skill + dispatch case

tests/
└── run.sh              # modified: add SKILL-01..SKILL-04 test block
```

No new directories needed.

### Pattern 1: Bash YAML Frontmatter Parsing

**What:** SKILL.md files start with a YAML frontmatter block (`---` delimiters). The frontmatter contains `name:`, `description:`, and optional fields. `jq` cannot parse YAML, so use bash + `sed`/`grep` to extract values.

**When to use:** Any time publish-skill.sh needs to read or validate frontmatter fields.

**How audit-setup.sh does it (existing precedent):**
```bash
# Source: scripts/audit-setup.sh lines 57-63 [VERIFIED: codebase read]
if ! head -10 "$skill" | grep -q '^name:'; then
  err "Skill '$name': missing 'name:' frontmatter"
fi
if ! head -10 "$skill" | grep -q '^description:'; then
  err "Skill '$name': missing 'description:' frontmatter"
elif head -10 "$skill" | grep -qE '^description: "?.{0,29}"?$'; then
  warn "Skill '$name': description very short (<30 chars)"
fi
```

**Extended pattern for publish-skill.sh (extract frontmatter block only):**
```bash
# Extract value from frontmatter (between opening --- and closing ---)
# Source: derived from audit-setup.sh pattern [ASSUMED — no existing extract function]
extract_frontmatter() {
  local file="$1" key="$2"
  # sed: print lines between first --- and second --- inclusive, then grep for key
  sed -n '1,/^---$/p' "$file" | grep "^${key}:" | head -1 | sed "s/^${key}: *//" | tr -d '"'
}
```

**Validation against schema constraints:**
```bash
# name pattern: ^[a-z][a-z0-9-]{1,40}$  (from skill.schema.json [VERIFIED: codebase read])
# description: minLength 30, maxLength 400
# name must match the parent directory name
```

**Why not use `jq` for frontmatter:** `jq` parses JSON only. SKILL.md frontmatter is YAML. A YAML parser (`yq`) is not in the project's runtime envelope. Bash grep + sed is the established pattern in this codebase. [VERIFIED: codebase read — audit-setup.sh uses grep/sed, no yq dependency anywhere]

### Pattern 2: Static Egress Scan (grep -nE)

**What:** Scan the SKILL.md body for patterns that indicate network exfiltration or sensitive env var references.

**When to use:** After frontmatter validation, before printing PR instructions.

**Example pattern (from D-01):**
```bash
# Source: CONTEXT.md D-01 decisions [VERIFIED: 11-CONTEXT.md read]
EGRESS_PATTERN='curl|wget|\bnc\b|fetch|http://|https://'
SENSITIVE_ENV='\$(HOME|USER|SECRET[^_=[:space:]])'

# Scan body only (skip frontmatter block)
# Use awk to skip lines 1 to the second --- marker
BODY="$(awk '/^---$/{n++} n>=2{print}' "$SKILL_FILE")"

if HITS="$(printf '%s\n' "$BODY" | grep -nE "$EGRESS_PATTERN" 2>/dev/null)"; then
  echo "✗ Egress scan failed — network patterns found:" >&2
  printf '%s\n' "$HITS" >&2
  exit 1
fi
if HITS="$(printf '%s\n' "$BODY" | grep -nE "$SENSITIVE_ENV" 2>/dev/null)"; then
  echo "✗ Egress scan failed — sensitive env var refs found:" >&2
  printf '%s\n' "$HITS" >&2
  exit 1
fi
```

**Key detail:** The TLMY-03 test in `tests/run.sh` (line 460) uses this egress pattern: `curl|fetch|http|socket|XMLHttpRequest|require\(.https.\)|require\(.http.\)|import.*https|import.*http|net\.Socket`. The SKILL pattern is narrower (bash-focused) — that's correct for SKILL.md content. [VERIFIED: tests/run.sh lines 459-463 read]

**Boundary question (Claude's Discretion):** Whether to scan the entire SKILL.md or only the body (after the frontmatter block). Scanning the body only is safer — frontmatter `description:` fields legitimately reference URLs in prose. Recommend: scan body only.

### Pattern 3: SHA-Pinning Guards (two distinct checks)

**What:** Two independent git checks, each with a distinct exit message.

**When to use:** Before any validation gate — fail fast.

**Example:**
```bash
# Guard 1: skill must be committed (D-07 check 1)
# Source: CONTEXT.md D-07 [VERIFIED: 11-CONTEXT.md read]
PORCELAIN="$(git -C "$TARGET" status --porcelain ".claude/skills/$SKILL_NAME/" 2>/dev/null)"
if [ -n "$PORCELAIN" ]; then
  echo "✗ Skill has uncommitted changes. Commit first:" >&2
  echo "    git add .claude/skills/$SKILL_NAME/ && git commit" >&2
  exit 1
fi

# Guard 2: conjure must be on a tagged release (D-07 check 2)
# Source: CONTEXT.md D-07 [VERIFIED: 11-CONTEXT.md read]
if ! git -C "$CONJURE_HOME" describe --exact-match HEAD 2>/dev/null; then
  echo "✗ Conjure version $CONJURE_VERSION is not a tagged release." >&2
  echo "  Run from a tagged commit." >&2
  exit 1
fi
```

**Note on exit codes:** D-08 specifies exit 1 for both SHA-pinning failures (user-fixable). Exit 2 is reserved for hard prereq failures (missing dep, missing file). [VERIFIED: CONTEXT.md Specific Ideas + publish-plugin.sh exit code comments]

### Pattern 4: PR Instruction Printing (Phase 10 pattern)

**What:** Print the `gh pr create` command when `gh` is present; print manual URL + checklist when absent.

**When to use:** After all validation gates pass.

**Existing Phase 10 pattern (publish-plugin.sh --submit path):**
```bash
# Source: scripts/publish-plugin.sh lines 138-146 [VERIFIED: codebase read]
echo "  [ ] Run: claude plugin validate . && ..."
echo "  [ ] Visit: https://claude.ai/settings/plugins/submit"
```

**For publish-skill.sh:**
```bash
# Default target repo
TARGET_REPO="${TARGET_REPO:-mohandoz/conjure}"
SKILL_PATH=".claude/skills/$SKILL_NAME/SKILL.md"

if command -v gh >/dev/null 2>&1; then
  echo "▸ conjure publish-skill: validation passed. Run this command to open the PR:"
  echo ""
  echo "  gh pr create \\"
  echo "    --repo $TARGET_REPO \\"
  echo "    --title \"feat(skills): add ${SKILL_NAME} skill\" \\"
  echo "    --body \"Contributes \`${SKILL_NAME}\` skill from \$(git -C \"\$TARGET\" rev-parse --short HEAD)\" \\"
  echo "    --head \$(git branch --show-current)"
else
  echo "▸ conjure publish-skill: validation passed. \`gh\` not found — open PR manually:"
  echo ""
  echo "  1. Push your branch: git push -u origin \$(git branch --show-current)"
  echo "  2. Visit: https://github.com/$TARGET_REPO/compare"
  echo "  3. Select your branch and create a PR with title: feat(skills): add ${SKILL_NAME} skill"
  echo "  4. Attach the file: $SKILL_PATH"
fi
```

**Note:** The PR body / title template is Claude's Discretion. The above is a starting point for the planner to refine.

### Pattern 5: Test Sandbox (from MKTPL pattern)

**What:** The MKTPL regression tests (lines 762-888 of tests/run.sh) create an isolated git repo sandbox, copy only the script + lib into it, then run the script against that sandbox. This prevents any writes to the real project files. [VERIFIED: tests/run.sh lines 762-888 read]

**Adaptation for SKILL tests:**
```bash
# Create sandbox with a real git repo, committed SKILL.md
SKILL_DIR="$(mktemp -d)"
git -C "$SKILL_DIR" init -q
git -C "$SKILL_DIR" config user.email "test@conjure"
git -C "$SKILL_DIR" config user.name "conjure-test"
mkdir -p "$SKILL_DIR/.claude/skills/test-skill"
# Write a clean SKILL.md to the sandbox
printf -- '---\nname: test-skill\ndescription: A test skill with exactly thirty characters or more to meet minimum\n---\n\n# test-skill\nSome content here.\n' \
  > "$SKILL_DIR/.claude/skills/test-skill/SKILL.md"
git -C "$SKILL_DIR" add -A
git -C "$SKILL_DIR" commit -q -m "add test-skill"

# Copy script + lib into sandbox
mkdir -p "$SKILL_DIR/scripts" "$SKILL_DIR/lib"
cp "$CONJURE_HOME/scripts/publish-skill.sh" "$SKILL_DIR/scripts/"
cp "$CONJURE_HOME/lib/mutate.sh"            "$SKILL_DIR/lib/"
cp "$CONJURE_HOME/VERSION"                  "$SKILL_DIR/VERSION"

# Tag the sandbox HEAD so the "tagged release" guard passes
git -C "$SKILL_DIR" tag "v$(cat "$CONJURE_HOME/VERSION")"

# Run tests against the sandbox copy...
```

### Anti-Patterns to Avoid

- **Scanning the frontmatter for egress:** The frontmatter `description:` field may legitimately reference URLs in prose. Scan body only (after the closing `---` delimiter). [ASSUMED — no test covers this specifically, but consistent with D-01's intent]
- **Using `exit 1` for missing deps:** Missing `jq` or `git` must be `exit 2` (hard prereq failure), not `exit 1` (user-fixable). See publish-plugin.sh lines 45-53 for the correct pattern. [VERIFIED: codebase read]
- **Running `gh pr create` directly:** D-03 is explicit: print the command, do not execute it. Any `gh pr create` call in the script is a bug. [VERIFIED: CONTEXT.md D-03]
- **Bypassing lib/mutate.sh for writes:** If the script writes any file (e.g., a plugin.json stub), it MUST go through `mutate_write`. If publish-skill.sh only prints to stdout (no files written), `mutate_summary` should still be called to handle the DRY_RUN=1 case cleanly. [VERIFIED: lib/mutate.sh + ARCHITECTURE.md]
- **Combined SHA-pinning error message:** D-08 requires two distinct per-failure messages. A single combined guard ("skill dirty OR not tagged") is wrong. [VERIFIED: CONTEXT.md D-08]
- **Positional skill name vs flag:** The command is `conjure publish-skill <name>`, not `--skill=<name>`. The name is a positional argument. See how `cmd_migrate` handles its positional `source` arg for the pattern. [VERIFIED: cli/conjure cmd_migrate lines 111-131]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dry-run suppression | Custom `if DRY_RUN` branches | `source lib/mutate.sh` + `mutate_write` | Already handles counter, summary, idempotency |
| Git dirty-tree check | Custom file-comparison logic | `git status --porcelain <path>` | Single authoritative command, handles all edge cases |
| Git tag check | Parsing `git log` or `git tag --list` | `git describe --exact-match HEAD` | Fails cleanly when HEAD is not exactly tagged |
| YAML parsing | Hand-written YAML parser | `grep`/`sed` on known-schema frontmatter | Schema has only 5 fixed keys; full YAML parsing is over-engineering |
| PR execution | Auto-running `gh pr create` | Print command only (D-03) | Design decision — user controls when PR fires |

**Key insight:** Every complex sub-problem in this phase has a one-liner git/bash solution. The skill of this implementation is correct composition, not novel engineering.

---

## Common Pitfalls

### Pitfall 1: `nc` matches too broadly
**What goes wrong:** The pattern `nc` in `grep -E 'curl|wget|nc|fetch'` matches any occurrence of `nc` — including words like `announce`, `since`, `function`, `cancel`. This produces false positives on legitimate skill content.
**Why it happens:** `nc` (netcat) is a two-letter command; grep treats it as a substring.
**How to avoid:** Use word-boundary or context anchors: `\bnc\b` or `' nc '` (space-bounded). Alternatively: `(^| )nc( |$)`. Test against a real skill that contains "since" or "announce".
**Warning signs:** Egress scan blocks skills that contain common English words. [ASSUMED — based on grep behavior knowledge, not a test we ran]

### Pitfall 2: Frontmatter extraction reads past the block
**What goes wrong:** `grep '^name:' SKILL.md` will match any `name:` line anywhere in the document, not just the frontmatter block. A SKILL.md body section titled `### name: ...` would falsely satisfy the check.
**Why it happens:** Not scoping the read to the frontmatter block.
**How to avoid:** Scope all frontmatter reads to `head -10` (as audit-setup.sh does) or use `sed -n '1,/^---$/p'` to extract only the frontmatter section.
**Warning signs:** Validation passes for SKILL.md files that have no frontmatter block at all. [VERIFIED: audit-setup.sh uses head -10 for exactly this reason]

### Pitfall 3: SHA-pinning checks run in wrong directory context
**What goes wrong:** `git status --porcelain .claude/skills/<name>/` run from `$CONJURE_HOME` looks for the skill in the conjure repo, not the user's project. The skill lives in the user's project (cwd by default).
**Why it happens:** publish-plugin.sh runs everything with `git -C "$CONJURE_HOME"` — but that's wrong for the skill dirty-tree check.
**How to avoid:** Use two different git contexts: `git -C "$TARGET"` for the skill's dirty check (where TARGET defaults to cwd); `git -C "$CONJURE_HOME"` for the conjure version tag check.
**Warning signs:** Dirty check never detects uncommitted skills; or detects conjure's own tree as dirty. [ASSUMED — derived from the two-context requirement in D-07]

### Pitfall 4: `git describe --exact-match` in a sandbox test
**What goes wrong:** The test sandbox is a fresh `git init` repo with no tags. The version tag check `git describe --exact-match HEAD` always fails, so the test for the "clean path" (all gates pass) is impossible.
**Why it happens:** SHA-pinning guard rejects untagged HEADs.
**How to avoid:** `git tag v$(cat VERSION)` on the sandbox commit after the initial commit, before running the happy-path test. The MKTPL pattern does a similar trick by committing before running the live-run test. [VERIFIED: tests/run.sh lines 774-776 — commit before live test]
**Warning signs:** Happy-path SKILL-01 test always exits 1 with "not a tagged release" message.

### Pitfall 5: `DRY_RUN` env var vs `CONJURE_DRYRUN`
**What goes wrong:** publish-plugin.sh uses `DRY_RUN` (not `CONJURE_DRYRUN`). The CONTEXT.md mentions `CONJURE_DRYRUN`. These must be consistent.
**Why it happens:** CONTEXT.md uses the public env var name; publish-plugin.sh uses the internal name.
**How to avoid:** Inspect `publish-plugin.sh` line 21: `DRY_RUN="${DRY_RUN:-0}"`. The pattern is `--dry-run` flag sets `DRY_RUN=1` before calling the script with `DRY_RUN="$dryrun"`. Follow the same convention in `cmd_publish_skill`. [VERIFIED: cli/conjure lines 266-278 and publish-plugin.sh line 21]

### Pitfall 6: `cmd_publish_skill` missing positional arg handling
**What goes wrong:** `cmd_publish_skill` is called with `shift; cmd_publish_skill "$@"` in the dispatch. If no skill name is given, the script receives no positional arg and either reads empty string or fails with an obscure error.
**Why it happens:** No arg validation in the dispatch function.
**How to avoid:** `cmd_publish_skill` must check that `$1` (the skill name) is non-empty and exit 1 with a usage message if absent. Compare to `cmd_migrate` line 112: `[ -z "$source" ] && { echo "Usage: ..."; return 1; }`. [VERIFIED: cli/conjure lines 111-112]

### Pitfall 7: Egress scan false negative — body scan starting position
**What goes wrong:** When extracting the body (everything after the frontmatter `---`), an off-by-one in `awk` or `sed` could include the frontmatter itself in the scan, or skip the first body line.
**Why it happens:** SKILL.md structure is: `---\n[frontmatter]\n---\n\n[body]`. The second `---` is the closing delimiter. `awk 'n>=2'` after counting `---` occurrences is correct; `n>=1` would include the frontmatter.
**Warning signs:** Egress scan hits on `---` lines or frontmatter values. [ASSUMED — derive from SKILL.md structure]

---

## Code Examples

### Complete arg-parsing skeleton (from cmd_publish template)

```bash
# Source: cli/conjure cmd_publish lines 264-278 [VERIFIED: codebase read]
cmd_publish_skill() {
  local skill_name="" target_repo="mohandoz/conjure" dryrun=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --to)        shift; target_repo="${1:-}" ;;
      --to=*)      target_repo="${1#--to=}" ;;
      --dry-run)   dryrun=1 ;;
      --help|-h)   echo "Usage: conjure publish-skill <name> [--to <org/repo>] [--dry-run]"; return 0 ;;
      -*)          echo "Unknown option: $1"; return 1 ;;
      *)           skill_name="$1" ;;
    esac
    shift
  done
  [ -z "$skill_name" ] && { echo "Usage: conjure publish-skill <name> [--to <org/repo>] [--dry-run]"; return 1; }
  CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" TARGET_REPO="$target_repo" \
    bash "$CONJURE_HOME/scripts/publish-skill.sh" "$skill_name"
}
```

### Dispatch table insertion point

```bash
# Source: cli/conjure lines 289-301 [VERIFIED: codebase read]
# Insert before the wildcard case:
  publish-skill)    shift; cmd_publish_skill "$@"    ;;
```

### Frontmatter field extraction (bash, no yq)

```bash
# Source: derived from audit-setup.sh pattern [ASSUMED — no extract function exists yet]
# Extract the frontmatter block (lines 1 to closing ---)
FM_BLOCK="$(sed -n '1,/^---$/p' "$SKILL_FILE" | grep -v '^---$')"
SKILL_NAME_FM="$(printf '%s\n' "$FM_BLOCK" | grep '^name:' | head -1 | sed 's/^name: *//' | tr -d '"')"
SKILL_DESC="$(printf '%s\n' "$FM_BLOCK" | grep '^description:' | head -1 | sed 's/^description: *//' | tr -d '"')"
```

### Size cap check

```bash
# Source: tests/run.sh lines 63-68 [VERIFIED: codebase read]
LINES="$(wc -l < "$SKILL_FILE" | tr -d ' ')"
if [ "$LINES" -gt 200 ]; then
  echo "✗ Skill exceeds 200-line cap ($LINES lines). Trim before publishing." >&2
  exit 1
fi
```

### Egress body scan (recommended approach)

```bash
# Body = everything after the closing frontmatter ---
# awk: count --- markers; when count >= 2, print
BODY="$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_FILE")"

EGRESS_HIT=0
if HITS="$(printf '%s\n' "$BODY" | grep -nE 'curl|wget|\bnc\b|fetch|http://|https://' 2>/dev/null)"; then
  [ -n "$HITS" ] && { echo "✗ Egress scan: network patterns found:" >&2; printf '%s\n' "$HITS" >&2; EGRESS_HIT=1; }
fi
if HITS="$(printf '%s\n' "$BODY" | grep -nE '\$(HOME|USER|SECRET)' 2>/dev/null)"; then
  [ -n "$HITS" ] && { echo "✗ Egress scan: sensitive env var refs found:" >&2; printf '%s\n' "$HITS" >&2; EGRESS_HIT=1; }
fi
[ "$EGRESS_HIT" -eq 1 ] && exit 1
```

**Note on `nc` pattern:** `\bnc\b` uses a POSIX word-boundary escape. GNU grep supports `\b`; BSD grep (macOS) also supports it. Test on both. If portability is a concern, use `(^| )nc( |$|;)` instead. [ASSUMED — based on grep man pages, not a live test]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N/A (new command) | bash-only, no new deps | Phase 11 | Consistent with CLAUDE.md zero-dep constraint |
| exit 1 for all errors | exit 1 = validation, exit 2 = hard prereq | Established in Phase 10 | publish-skill.sh must follow same convention |
| Print and execute gh | Print only (D-03) | Phase 10 decision | User controls when PR fires |

**Deprecated/outdated:**
- `CONJURE_DRYRUN` as the env var name: the actual implementation uses `DRY_RUN` internally. CONTEXT.md references `CONJURE_DRYRUN` as the documented public name; `cmd_publish_skill` passes it as `DRY_RUN` to the script. This is consistent with publish-plugin.sh — no change needed.

---

## D-06 Resolution (Claude's Discretion): What Gets Submitted

**Decision:** Submit only the SKILL.md file (not a plugin.json stub). Rationale:

The contribution convention for `mohandoz/conjure` is to add skills to `templates/skills/<name>/SKILL.md`. There is no per-skill `plugin.json` in the conjure repo — skills are part of the conjure plugin, not standalone plugins. The `plugin.json` stub mentioned in ARCHITECTURE.md §3 refers to the case where a skill is contributed as a *standalone* plugin to a different marketplace — that is out of scope for Phase 11 (which targets `mohandoz/conjure` and `--to` repos). [VERIFIED: templates/skills/ structure — no plugin.json files exist per-skill]

The `gh pr create` command should reference the branch containing the committed skill, letting the PR diff show the SKILL.md addition. No file staging by the script is needed — the skill is already committed (required by D-07 check 1).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Hand-rolled bash (tests/run.sh) |
| Config file | none |
| Quick run command | `bash tests/run.sh` |
| Full suite command | `bash tests/run.sh` (single suite) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SKILL-01 | Frontmatter validation blocks missing/invalid fields | unit (bash) | `bash tests/run.sh` (SKILL-01 block) | No — Wave 0 |
| SKILL-01 | Size cap (>200 lines) exits 1 | unit (bash) | `bash tests/run.sh` (SKILL-01 block) | No — Wave 0 |
| SKILL-01 | Egress scan blocks curl/wget/nc/fetch/http/https | unit (bash) | `bash tests/run.sh` (SKILL-01 block) | No — Wave 0 |
| SKILL-01 | Egress scan blocks $HOME/$USER/$SECRET | unit (bash) | `bash tests/run.sh` (SKILL-01 block) | No — Wave 0 |
| SKILL-01 | Clean skill passes all gates | unit (bash) | `bash tests/run.sh` (SKILL-01 block) | No — Wave 0 |
| SKILL-01 | --dry-run suppresses no file mutations | unit (bash) | `bash tests/run.sh` (SKILL-01 block) | No — Wave 0 |
| SKILL-02 | gh present → prints gh pr create command (does not exec) | unit (bash) | `bash tests/run.sh` (SKILL-02 block) | No — Wave 0 |
| SKILL-02 | gh absent → prints manual URL + checklist | unit (bash) | `bash tests/run.sh` (SKILL-02 block) | No — Wave 0 |
| SKILL-03 | Dirty skill tree → exit 1 with correct message | unit (bash) | `bash tests/run.sh` (SKILL-03 block) | No — Wave 0 |
| SKILL-03 | Untagged conjure HEAD → exit 1 with correct message | unit (bash) | `bash tests/run.sh` (SKILL-03 block) | No — Wave 0 |
| SKILL-04 | --to <org/repo> → correct repo in printed command | unit (bash) | `bash tests/run.sh` (SKILL-04 block) | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `bash tests/run.sh`
- **Per wave merge:** `bash tests/run.sh`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] SKILL-01 through SKILL-04 test block in `tests/run.sh` — follows MKTPL sandbox pattern (lines 762-888)
- [ ] `scripts/publish-skill.sh` — new worker script
- [ ] `cmd_publish_skill` + dispatch case in `cli/conjure`

*(No new test infrastructure needed — tests/run.sh and its sandbox.sh lib are already in place.)*

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | All scripts | Yes | zsh host / bash subprocess | — |
| jq | Frontmatter JSON operations (if any) / JSON validation | Yes (preflight dep) | varies | exit 2 + "install jq" message |
| git | SHA-pinning guards | Yes (preflight dep) | 2.x | exit 2 + "install git" message |
| gh | PR command printing | Optional | varies | print manual URL + checklist |
| shellcheck | CI lint | Yes (CI dep) | 0.x | — |

**Missing dependencies with no fallback:** none — jq and git are pre-existing preflight requirements.

**Missing dependencies with fallback:** `gh` — fallback is manual URL + checklist (D-04, already decided).

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | Yes | Frontmatter field validation via grep/sed + schema constraints |
| V6 Cryptography | No | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Skill name path traversal (`../` in name) | Tampering | Validate name matches `^[a-z][a-z0-9-]{1,40}$` (schema pattern) before constructing path |
| Egress in frontmatter description | Information Disclosure | Scan body only — frontmatter prose is not executable |
| `--to` injection (`; rm -rf /` in org/repo arg) | Tampering | Only use `TARGET_REPO` in printed strings, never in `eval` or `bash -c` calls |
| Shell injection via SKILL_NAME | Tampering | Quote all `$SKILL_NAME` expansions; validate with regex before any path construction |

**Key invariant:** publish-skill.sh never executes `gh pr create` — it only prints a string. This eliminates an entire class of injection via the PR title/body fields. [VERIFIED: D-03 decision]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `\bnc\b` word-boundary works equivalently in GNU grep and BSD grep | Code Examples (egress scan) | False positives on macOS if BSD grep ignores `\b`; mitigation: use `(^| )nc[ ;$]` instead |
| A2 | Scanning body only (not frontmatter) is the correct egress scan scope | Architecture Patterns / Common Pitfalls | If a skill has egress in a frontmatter description, it would be missed; low risk because frontmatter description is prose, not executable |
| A3 | No plugin.json stub is needed — SKILL.md-only submission matches contribution conventions | D-06 Resolution section | If `mohandoz/conjure` actually requires a plugin.json entry per-skill, the PR would need additional files; medium risk; verify by checking existing PR history in the repo |
| A4 | `awk` body extraction (`n>=2`) correctly skips frontmatter for all SKILL.md files | Code Examples | If a SKILL.md has only one `---` (malformed), the body would not be extracted; mitigated by frontmatter validation gate (which would catch the malformed frontmatter first) |

---

## Open Questions

1. **`$SECRET` pattern specificity**
   - What we know: D-01 says `$HOME`, `$USER`, `$SECRET` and "common variants"
   - What's unclear: What are the "common variants"? `$SECRETS`? `$SECRET_KEY`? `$API_KEY`? `$TOKEN`? `$PASSWORD`?
   - Recommendation: Use `\$(HOME|USER|SECRET|API_KEY|TOKEN|PASSWORD)` as a reasonable set; planner should confirm with user or pick a broad pattern that errs on the side of more blocking

2. **`--to` flag format validation**
   - What we know: D-05 says `--to <org/repo>` substitutes the target repo in the printed command
   - What's unclear: Should the script validate that `<org/repo>` matches the `owner/repo` format? Or pass it through verbatim?
   - Recommendation: Validate with `echo "$TARGET_REPO" | grep -qE '^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$'` before use; exit 1 with usage message if malformed

3. **PR branch reference in the printed command**
   - What we know: D-03 says print `gh pr create`; the skill is already committed
   - What's unclear: Should the printed command include `--head $(git branch --show-current)` or `--head <sha>`?
   - Recommendation: Use `$(git branch --show-current)` — more readable; the user runs this command themselves so they control context

---

## Sources

### Primary (HIGH confidence)
- `scripts/publish-plugin.sh` — full content read this session; structural template for publish-skill.sh
- `cli/conjure` — full content read this session; dispatch pattern and cmd_publish blueprint
- `lib/mutate.sh` — full content read this session; write chokepoint API
- `.claude-plugin/SCHEMAS/skill.schema.json` — full content read this session; schema constraints
- `tests/run.sh` — full content read this session; test conventions and MKTPL sandbox pattern
- `scripts/audit-setup.sh` — partial read this session; frontmatter parsing pattern (grep-based)
- `.planning/phases/11-skill-publishing/11-CONTEXT.md` — full content read this session; locked decisions
- `.planning/REQUIREMENTS.md` — full content read this session; SKILL-01 through SKILL-04
- `.planning/research/ARCHITECTURE.md` — full content read this session; component design
- `.github/workflows/ci.yml` — full content read this session; shellcheck glob confirmed

### Secondary (MEDIUM confidence)
- `.planning/ROADMAP.md` Phase 11 section — success criteria confirmed
- `templates/skills/debugging/SKILL.md` — SKILL.md format confirmed

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are existing preflight deps; confirmed from codebase
- Architecture: HIGH — all patterns derived directly from existing code in the same repo
- Pitfalls: MEDIUM — pitfall 1 (nc word boundary) and pitfall 7 (body extraction) are ASSUMED; others VERIFIED
- Test patterns: HIGH — MKTPL sandbox pattern read directly from tests/run.sh

**Research date:** 2026-05-25
**Valid until:** 2026-06-25 (stable domain; only changes if CONTEXT.md is re-opened)
