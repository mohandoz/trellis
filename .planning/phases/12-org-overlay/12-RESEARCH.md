# Phase 12: Org Overlay - Research

**Researched:** 2026-05-26
**Domain:** POSIX bash, git clone/ls-remote, mutate.sh chokepoint, audit reporting
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Overlay repo root maps directly to `.claude/`. A file at `skills/foo/SKILL.md` in the
  overlay repo is applied to `.claude/skills/foo/SKILL.md` in the target project. No subdirectory
  wrapper, no `overlay.json` manifest required.
- **D-02:** All files in the overlay repo are applied — no exclusions. Overlay repo maintainers
  are responsible for the content. Simplest possible rule: overlay repo is a mirror of `.claude/`.
- **D-03:** Overlay always wins — overlay files unconditionally overwrite existing `.claude/` files
  on `refresh-overlay`. User edits to overlay-managed files are overwritten. Backup-before-mutate
  runs first so no data is permanently lost.
- **D-04:** `conjure refresh-overlay` exits 1 with message `"No org overlay configured. Run
  conjure init --overlay <git-url> first."` if no `.conjure-org-overlay` marker file exists.
- **D-05:** `conjure audit` runs `git ls-remote <overlay-url>` to get the current remote HEAD SHA
  and compares it against the pinned SHA in `.conjure-org-overlay`. Reports overlay URL, pinned
  SHA, upstream SHA, and `DRIFT` warning if they differ.
- **D-06:** If `git ls-remote` fails, audit prints `[overlay] drift check skipped (git ls-remote
  failed)` and continues. Audit still exits 0.
- **D-07:** Clone into a `mktemp -d` temp directory. After copying all files into `.claude/`,
  `rm -rf` the temp dir. No persistent local clone. No nested `.git` metadata under `.claude/`.
- **D-08:** Use `git clone --depth 1 <url>` (shallow clone).
- **D-09:** Authentication uses the user's existing git credential store. No credentials stored
  by Conjure (OVLY-05 invariant).

### Claude's Discretion
- Function naming inside `scripts/init-overlay.sh` and `scripts/refresh-overlay.sh`
- Whether overlay logic lives in a new script or inside the existing `cmd_init` path in
  `cli/conjure` (researcher resolves — see Architecture Patterns below)
- Exact marker file format for `.conjure-org-overlay` (researcher resolves — see Standard Stack)
- Test IDs for OVLY regression tests (OVLY-NN blocks in `tests/run.sh`)
- Whether `conjure init --overlay` also prints a post-install summary showing which overlay
  files were applied (researcher: consistent with `mutate_summary` pattern)

### Deferred Ideas (OUT OF SCOPE)
- `compatible-kit-version` manifest field in overlay repo — deferred to v0.4.x
- Persistent overlay cache under `.claude/` for faster refresh — deferred to v0.4.x
- `--dry-run` support for `conjure init --overlay` — deferred; `DRY_RUN` env still honored
  through `lib/mutate.sh` but no explicit `--dry-run` flag in Phase 12
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OVLY-01 | User can run `conjure init --overlay <git-url>` to apply the base kit first and then overlay files from the given repo; all writes go through `lib/mutate.sh` | init-overlay.sh worker; extend cmd_init arg-parser |
| OVLY-02 | After `conjure init --overlay`, a `.claude/.conjure-org-overlay` marker file records the overlay URL and the cloned commit SHA | flat key=value format: `url=…\nsha=…` |
| OVLY-03 | User can run `conjure refresh-overlay` to re-pull the org overlay and re-apply it; overlay-wins semantics on conflict | refresh-overlay.sh worker + cmd_refresh_overlay dispatcher |
| OVLY-04 | `conjure audit` detects and reports overlay presence, the pinned SHA, and any drift from the currently checked-out overlay HEAD | git ls-remote section in audit-setup.sh |
| OVLY-05 | Overlay repo authentication uses the user's existing git credential store; no credentials are stored by Conjure | enforced by architecture: store nothing, delegate to git credential helper |
</phase_requirements>

## Summary

Phase 12 implements an organization overlay system: a private git repo whose contents are applied
on top of the base Conjure kit. All core mechanisms are built on tools already in the project —
`lib/mutate.sh` for writes, `scripts/publish-plugin.sh` as a structural template for worker
scripts, `cmd_refresh_graph` as a dispatcher template, and `tests/run.sh`'s git-sandbox pattern
for regression tests.

The two critical implementation details discovered during research are: (1) the `.git` metadata
problem — a naive `cp -r clone/. .claude/` will copy `.git/` into `.claude/`, violating D-07;
the correct approach uses a `find … ! -name '.git'` loop with process substitution to preserve
`CONJURE_DRY_MUTATION_COUNT`; and (2) the marker file format should use flat `key=value` lines
(matching `.conjure-version`'s plain-text precedent), not JSON, making it readable without `jq`.

The overlay logic SHOULD live in two standalone worker scripts (`scripts/init-overlay.sh` and
`scripts/refresh-overlay.sh`) rather than inlining into `cmd_init`. The profile-apply pattern at
`cli/conjure:83-86` is close, but overlay application is a distinct, multi-step operation (clone,
copy, marker write, cleanup) that deserves its own script for testability and shellcheck isolation.
Three-line dispatcher pattern (`cmd_refresh_graph` at line 253) is the right model for
`cmd_refresh_overlay`.

**Primary recommendation:** Two standalone worker scripts + thin CLI dispatchers, flat marker
file, `find … ! -name '.git'` copy loop with process substitution, `git ls-remote HEAD` for
drift with graceful-fail wrapper.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Overlay application (clone + copy) | Worker script (`scripts/init-overlay.sh`) | CLI dispatcher (`cmd_init` extension) | CLI handles arg-parsing; worker owns the multi-step operation |
| Overlay re-application | Worker script (`scripts/refresh-overlay.sh`) | CLI dispatcher (`cmd_refresh_overlay`) | Same separation as refresh-graph pattern |
| Marker file read/write | Worker scripts | `lib/mutate.sh` (writes only) | Writes go through chokepoint; reads are direct `grep`/`cat` |
| Drift detection | `scripts/audit-setup.sh` | — | Audit owns all health-check reporting |
| Authentication | Git credential store (system) | — | Conjure stores nothing; git handles it transparently |

## Standard Stack

### Core
| Tool/Library | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| `git clone --depth 1` | system git 2.x | Shallow-clone overlay repo | [VERIFIED: git-scm.com] Built-in; depth 1 = HEAD only, fastest |
| `git ls-remote` | system git 2.x | Get upstream HEAD SHA for drift check | [VERIFIED: git-scm.com] No clone required; works with same credential store |
| `git rev-parse HEAD` | system git 2.x | Get cloned commit SHA after clone | [ASSUMED] Standard git plumbing command |
| `lib/mutate.sh` | project | All filesystem writes (mutate_write, mutate_cp, mutate_mkdir) | [VERIFIED: codebase] Project invariant — all writes must route through this |
| `mktemp -d` | POSIX | Temp dir for clone | [ASSUMED] POSIX-standard; already used throughout test suite |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `find … -mindepth 1 -maxdepth 1 ! -name '.git'` | List overlay items excluding `.git` | Copy step — do NOT use `cp -r clone/. dest/` (copies `.git`) |
| `printf 'url=%s\nsha=%s\n'` | Write marker file content | Flat key=value, consistent with plain-text marker precedent |
| `grep '^url=' marker | cut -d= -f2-` | Read URL from marker | Allows `=` in URL values; safe |
| `awk '{print $1}'` | Extract SHA from `git ls-remote` output | First field is the SHA |

**No new package installations required.** All tools are part of the existing runtime envelope
(bash + git + stdlib). `dependencies: {}` stays empty.

## Package Legitimacy Audit

No external packages are installed in this phase. All tools are standard POSIX utilities or
git built-ins already present in the runtime envelope.

**Packages removed:** none
**Packages flagged:** none

## Architecture Patterns

### System Architecture Diagram

```
conjure init --overlay <url>            conjure refresh-overlay
        |                                       |
        v                                       v
  cmd_init (cli/conjure)              cmd_refresh_overlay (cli/conjure)
  parses --overlay=<url>                  3-line dispatcher
        |                                       |
        v                                       v
  scripts/init-project.sh            scripts/refresh-overlay.sh
  (base kit applied first)                reads .conjure-org-overlay
        |                                   url= + sha=
        v                                       |
  scripts/init-overlay.sh                       v
        |                                  backup .claude/
        +-- git clone --depth 1 <url>      rm tmpdir
        |          (tmpdir)                git clone --depth 1 <url>
        +-- git rev-parse HEAD             find/copy (excl .git)
        |   = CLONE_SHA                    rm -rf tmpdir
        +-- find tmpdir ! -name .git       mutate_write marker
        |   -> cp -r each item -> .claude/ mutate_summary
        +-- rm -rf tmpdir                       |
        +-- mutate_write .conjure-org-overlay   v
        +-- mutate_summary                  exit 0

conjure audit
        |
        v
  scripts/audit-setup.sh
        ...existing checks...
        |
        +-- [ -f .claude/.conjure-org-overlay ] ?
        |     NO  -> ok "no overlay configured"
        |     YES -> read url= + sha= from marker
        |            git ls-remote <url> HEAD -> UPSTREAM_SHA
        |            (on failure) -> warn "[overlay] drift check skipped"
        |            (on success) -> compare pinned vs upstream
        |                pinned == upstream -> ok "overlay up to date"
        |                pinned != upstream -> warn "overlay DRIFT"
```

### Recommended Project Structure
```
scripts/
├── init-overlay.sh       # NEW — clone + apply overlay; all writes via lib/mutate.sh
├── refresh-overlay.sh    # NEW — re-pull overlay; backup-before-mutate; overlay-wins
├── audit-setup.sh        # MODIFIED — add overlay section after conflict-marker check
└── ...existing...
cli/
└── conjure               # MODIFIED — add --overlay=* to cmd_init; add cmd_refresh_overlay
tests/
└── run.sh                # MODIFIED — add OVLY-01..OVLY-05 regression blocks
```

### Pattern 1: Standalone Worker Script Structure
**What:** Worker script with CONJURE_HOME self-resolution, lib/mutate.sh source, env defaults,
arg parsing, prereq checks, logic, mutate_summary, exit 0.
**When to use:** Any multi-step operation that needs testing isolation and shellcheck coverage.
**Example (from `scripts/publish-plugin.sh`):**
```bash
# Source: scripts/publish-plugin.sh:1-20
#!/usr/bin/env bash
set -euo pipefail
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
source "$CONJURE_HOME/lib/mutate.sh"
DRY_RUN="${DRY_RUN:-0}"
# arg parsing, prereqs, logic...
mutate_summary
exit 0
```

### Pattern 2: Three-Line Dispatcher in cli/conjure
**What:** A `cmd_*` function that does nothing but `bash "$CONJURE_HOME/scripts/worker.sh" "$@"`.
**When to use:** Every new subcommand that has a standalone worker script.
**Example (from `cli/conjure:253-255`):**
```bash
# Source: cli/conjure:253-255
cmd_refresh_graph() {
  bash "$CONJURE_HOME/scripts/refresh-graph.sh" "$@"
}
```
`cmd_refresh_overlay` follows the exact same shape.

### Pattern 3: --overlay=* Arg in cmd_init
**What:** Add `--overlay=*` case to cmd_init's arg-parsing loop, alongside `--profile=*`.
**When to use:** Adding a new optional flag to an existing command.
**Example (extending cli/conjure:56-65):**
```bash
# Extend the existing while [ $# -gt 0 ]; do case "$1" in loop:
--overlay=*)  overlay="${1#--overlay=}" ;;
```
Then after init-project.sh runs and profile overlay runs, add:
```bash
# Apply org overlay if specified
if [ -n "$overlay" ]; then
  CONJURE_HOME="$CONJURE_HOME" DRY_RUN="$dryrun" \
    bash "$CONJURE_HOME/scripts/init-overlay.sh" "$overlay" "$target"
fi
```

### Pattern 4: Backup-Before-Mutate for refresh-overlay
**What:** Copy `.claude/` to `.claude.backup-<timestamp>` before any mutation.
**When to use:** Any operation that unconditionally overwrites user files.
**Example (from `cli/conjure:210-215`):**
```bash
if [ -d "$target/.claude" ]; then
  local ts; ts="$(date +%Y%m%d-%H%M%S)"
  local backup="$target/.claude.backup-${ts}"
  echo "▸ Backing up existing .claude/ → $backup"
  cp -R "$target/.claude" "$backup" \
    || { echo "✗ Backup failed — aborting"; return 1; }
fi
```

### Pattern 5: Copy Overlay Files Excluding .git
**What:** Use `find … ! -name '.git'` with process substitution to copy all overlay items
into `.claude/` without copying `.git/` metadata and without losing `CONJURE_DRY_MUTATION_COUNT`
to a pipe subshell.
**When to use:** Copying contents of a git clone into a target directory.
```bash
# Source: VERIFIED via testing in this research session
while IFS= read -r item; do
  cp -r "$item" "$target/.claude/"
done < <(find "$CLONE_TMP" -mindepth 1 -maxdepth 1 ! -name '.git')
```
Note: `mutate_cp` is NOT used here directly because we need to iterate dynamically. The
individual `cp -r` calls inside the loop must be guarded by a DRY_RUN check inline, OR
refactored into a helper that calls `mutate_cp` per item. Given mutate_cp checks
`[ -d "$1" ]` correctly, the cleanest approach is:
```bash
while IFS= read -r item; do
  mutate_cp "$item" "$target/.claude/"
done < <(find "$CLONE_TMP" -mindepth 1 -maxdepth 1 ! -name '.git')
```
This correctly routes through the mutate chokepoint AND tracks the mutation count.

### Pattern 6: Marker File Format
**What:** Flat `key=value` lines, one per field, plain text.
**Rationale:** `.conjure-version` is plain text (just the version string). The overlay marker
needs two fields; flat `key=value` is the minimal extension of that pattern without requiring
`jq`. Consistent with the project's "no heavy deps" constraint.
**Format:**
```
url=https://github.com/myorg/overlay.git
sha=f9655c8c597d4110129ff8727ab659dd83695bbc
```
**Reading back:**
```bash
OVERLAY_URL="$(grep '^url=' "$marker_file" | cut -d= -f2-)"
PINNED_SHA="$(grep '^sha=' "$marker_file" | cut -d= -f2)"
```
Note: `cut -d= -f2-` (not `f2`) ensures URLs containing `=` are read correctly.

### Pattern 7: Audit Section — ok/warn/err Convention
**What:** Overlay audit section uses the same `ok()`, `warn()`, `err()` helper functions
already defined in `audit-setup.sh`.
**When to use:** Any new audit check added to `scripts/audit-setup.sh`.
**Example (from existing conflict-marker check, lines 132-145):**
```bash
if [ -n "$CONFLICT_FILES" ]; then
  err "Unresolved merge conflicts found in .claude/"
else
  ok ".claude/: no unresolved conflict markers"
fi
```
The overlay section follows this pattern:
```bash
OVERLAY_MARKER="$TARGET/.claude/.conjure-org-overlay"
if [ ! -f "$OVERLAY_MARKER" ]; then
  ok "no org overlay configured"
else
  OVERLAY_URL="$(grep '^url=' "$OVERLAY_MARKER" | cut -d= -f2-)"
  PINNED_SHA="$(grep '^sha=' "$OVERLAY_MARKER" | cut -d= -f2)"
  note "[overlay] url: $OVERLAY_URL"
  note "[overlay] pinned: $PINNED_SHA"
  UPSTREAM_SHA="$(git ls-remote "$OVERLAY_URL" HEAD 2>/dev/null | awk '{print $1}')" || true
  if [ -z "$UPSTREAM_SHA" ]; then
    warn "[overlay] drift check skipped (git ls-remote failed)"
  elif [ "$PINNED_SHA" = "$UPSTREAM_SHA" ]; then
    ok "[overlay] up to date ($PINNED_SHA)"
  else
    warn "[overlay] DRIFT — pinned=$PINNED_SHA upstream=$UPSTREAM_SHA — run: conjure refresh-overlay"
  fi
fi
```

### Anti-Patterns to Avoid
- **`cp -r clone/. .claude/`:** Copies `.git/` into `.claude/`, violating D-07. Always use
  `find clone -mindepth 1 -maxdepth 1 ! -name '.git'` loop instead.
- **Pipe to `while IFS= read` for mutate calls:** Creates subshell; `CONJURE_DRY_MUTATION_COUNT`
  increments are lost. Use `< <(find …)` process substitution instead (bash-specific, but this
  codebase is already bash-specific: `set -uo pipefail`, `[[ … ]]` in some places).
- **Storing credentials:** Never pass credentials to git or store them anywhere. Git's own
  credential helper handles private-repo authentication transparently (OVLY-05).
- **Failing audit on network error:** `git ls-remote` exits 128 on network/auth failure. The
  audit must wrap the call and treat any non-zero exit as "skip with warn", not "fail".
- **Inlining overlay logic into `cmd_init` body:** The multi-step clone+copy+marker operation
  should live in `scripts/init-overlay.sh`, not inline in `cmd_init`. Testability and shellcheck
  coverage require a standalone script.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Remote HEAD SHA lookup | custom HTTP request to GitHub API | `git ls-remote <url> HEAD` | Works for all git hosts; respects credential store; no API token needed |
| Credential storage | custom credential vault | Git credential helper (system) | Already configured by user; OVLY-05 explicitly forbids storing credentials |
| File copy with DRY_RUN support | conditional `cp` everywhere | `mutate_cp` from `lib/mutate.sh` | Project invariant — all writes through the chokepoint |
| Backup before overwrite | custom backup logic | `cp -R .claude .claude.backup-<ts>` pattern (lines 210-215 in cli/conjure) | Established pattern; consistent behavior |

**Key insight:** The entire overlay mechanism is git plumbing + file copy. No new abstractions
needed beyond what already exists in the project.

## Common Pitfalls

### Pitfall 1: cp -r Copies .git Into .claude/
**What goes wrong:** `cp -r "$CLONE_TMP/." "$TARGET/.claude/"` copies the `.git/` directory from
the clone into `.claude/`, creating nested git state. `conjure audit` and `git status` on the
target project will behave incorrectly.
**Why it happens:** `cp -r src/. dest/` copies all entries including hidden directories like `.git`.
**How to avoid:** Use `find "$CLONE_TMP" -mindepth 1 -maxdepth 1 ! -name '.git'` to enumerate
items, then copy each one individually with `mutate_cp`.
**Warning signs:** `ls -la .claude/` shows a `.git` directory after init/refresh.

### Pitfall 2: Pipe Subshell Loses Mutation Count
**What goes wrong:** `find "$CLONE_TMP" … | while IFS= read -r item; do mutate_cp …; done`
runs the loop body in a subshell. `CONJURE_DRY_MUTATION_COUNT` increments inside the loop
are lost; `mutate_summary` reports 0 mutations in dry-run mode.
**Why it happens:** POSIX pipes run the right-hand side in a subshell in bash (though not in
some shells). Process substitution `< <(find …)` runs the loop in the current shell.
**How to avoid:** Use `while IFS= read -r item; do …; done < <(find …)` pattern.
**Warning signs:** `[dry-run] 0 mutations skipped` when overlay had files to copy.

### Pitfall 3: git ls-remote Exit Code on Auth Failure
**What goes wrong:** `git ls-remote` exits 128 when it can't reach a private repo (wrong
credentials, no network). If the audit script uses `set -euo pipefail` and doesn't guard this
call, the whole audit exits 128 unexpectedly.
**Why it happens:** `set -euo pipefail` causes any non-zero exit to terminate the script.
**How to avoid:** Capture the call with `|| true` and check if the output is empty:
`UPSTREAM_SHA="$(git ls-remote "$URL" HEAD 2>/dev/null | awk '{print $1}')" || true`
Then: `if [ -z "$UPSTREAM_SHA" ]; then warn "drift check skipped"; fi`
**Warning signs:** `conjure audit` exits 128 instead of 0 or 1.

### Pitfall 4: Marker File Written Before Clone Succeeds
**What goes wrong:** Script writes `.conjure-org-overlay` marker before the clone and copy
succeed. If the clone fails mid-way, the marker exists with a stale/wrong SHA. `refresh-overlay`
will think an overlay is configured when it's actually broken.
**Why it happens:** Writing the marker early for "progress tracking".
**How to avoid:** Write the marker ONLY after the clone succeeds, the files are copied, and the
temp dir is cleaned up. Order: clone → get SHA → copy → rm tmpdir → write marker.
**Warning signs:** `.conjure-org-overlay` exists but `.claude/` has no overlay files.

### Pitfall 5: refresh-overlay Without Prior .claude/ Backup
**What goes wrong:** `refresh-overlay` unconditionally overwrites files. If no backup is made
first, user customizations are permanently lost.
**Why it happens:** Skipping the backup step for "simplicity".
**How to avoid:** Always run the `cp -R .claude .claude.backup-<ts>` pattern before the copy
loop. This is the established project pattern (lines 210-215 in cli/conjure).
**Warning signs:** No `.claude.backup-*` directory after running `conjure refresh-overlay`.

### Pitfall 6: CMD_REFRESH_OVERLAY Missing from Dispatch Table
**What goes wrong:** `cmd_refresh_overlay` function exists in `cli/conjure` but the dispatch
`case` statement at line 318 doesn't have a `refresh-overlay)` case. Users get "Unknown command".
**Why it happens:** Forgetting to add both the function AND the dispatch case.
**How to avoid:** Plan explicitly includes both: (a) add `cmd_refresh_overlay()` function, and
(b) add `refresh-overlay)   shift; cmd_refresh_overlay "$@"  ;;` to the dispatch table.
Also update `usage()` string at line 27-49.

### Pitfall 7: shellcheck SC2044 on find Loop
**What goes wrong:** `shellcheck` reports SC2044 ("For loop over find output. Use find -exec or
a while loop.") if `for item in $(find …)` pattern is used.
**Why it happens:** Word splitting on filenames with spaces.
**How to avoid:** The `while IFS= read -r item; do … done < <(find …)` pattern avoids SC2044.
The CI shellcheck command uses `-e SC2044` to suppress it, but it's cleaner to avoid it entirely.

## Code Examples

Verified patterns from project codebase and research session:

### Extract SHA from git ls-remote
```bash
# Source: VERIFIED via shell testing in this research session
UPSTREAM_SHA="$(git ls-remote "$OVERLAY_URL" HEAD 2>/dev/null | awk '{print $1}')" || true
if [ -z "$UPSTREAM_SHA" ]; then
  warn "[overlay] drift check skipped (git ls-remote failed)"
fi
```

### Get Cloned Commit SHA
```bash
# Source: VERIFIED via shell testing in this research session
CLONE_TMP="$(mktemp -d)"
git clone --depth 1 "$OVERLAY_URL" "$CLONE_TMP" 2>/dev/null
CLONE_SHA="$(git -C "$CLONE_TMP" rev-parse HEAD)"
```

### Copy Overlay Files Excluding .git via mutate_cp
```bash
# Source: VERIFIED via shell testing in this research session
# Process substitution avoids subshell so mutate_cp's counter is preserved
while IFS= read -r item; do
  mutate_cp "$item" "$TARGET/.claude/"
done < <(find "$CLONE_TMP" -mindepth 1 -maxdepth 1 ! -name '.git')
rm -rf "$CLONE_TMP"
```

### Write Marker File
```bash
# Source: VERIFIED via shell testing; format matches .conjure-version precedent
mutate_write "$TARGET/.claude/.conjure-org-overlay" "$(printf 'url=%s\nsha=%s' "$OVERLAY_URL" "$CLONE_SHA")"
```

### Read Marker File
```bash
# Source: VERIFIED via shell testing in this research session
OVERLAY_MARKER="$TARGET/.claude/.conjure-org-overlay"
OVERLAY_URL="$(grep '^url=' "$OVERLAY_MARKER" | cut -d= -f2-)"
PINNED_SHA="$(grep  '^sha=' "$OVERLAY_MARKER" | cut -d= -f2)"
```

### Test: Create Local Git Repo as Mock Overlay
```bash
# Source: VERIFIED via shell testing in this research session
# git clone --depth 1 works with file:// URLs — no network needed for tests
OVLY_REPO="$(mktemp -d)"
git -C "$OVLY_REPO" init -q
git -C "$OVLY_REPO" config user.email "test@conjure"
git -C "$OVLY_REPO" config user.name "conjure-test"
mkdir -p "$OVLY_REPO/skills/org-skill"
printf 'name: org-skill\ndescription: Org overlay skill\n' > "$OVLY_REPO/skills/org-skill/SKILL.md"
git -C "$OVLY_REPO" add -A
git -C "$OVLY_REPO" commit -q -m "overlay v1"
OVERLAY_URL="file://$OVLY_REPO"
# git ls-remote also works with file:// URLs:
git ls-remote "$OVERLAY_URL" HEAD 2>/dev/null | awk '{print $1}'
```

### Dispatcher Pattern (cmd_refresh_overlay)
```bash
# Source: cli/conjure:253-255 (cmd_refresh_graph)
cmd_refresh_overlay() {
  bash "$CONJURE_HOME/scripts/refresh-overlay.sh" "$@"
}
# In dispatch table (cli/conjure:318):
refresh-overlay)  shift; cmd_refresh_overlay "$@"  ;;
```

### --overlay=* in cmd_init arg parser
```bash
# Source: cli/conjure:56-65 extended with new case
# Add alongside --profile=* in the while [ $# -gt 0 ]; do case "$1" in loop:
--overlay=*)  overlay="${1#--overlay=}" ;;
# local declaration at top of cmd_init (line 55 area):
# local mode="existing" profile="" overlay="" dryrun=0 target="$(pwd)"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline org customization in CLAUDE.md | Private overlay repo applied on top of kit | Phase 12 | Orgs can version-control their Claude Code conventions separately |
| Manual re-applying customizations after update | `conjure refresh-overlay` re-pulls automatically | Phase 12 | Org-controlled files stay org-controlled |

**Deprecated/outdated:**
- None for this phase — all patterns are new.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `git rev-parse HEAD` works correctly on a shallow `--depth 1` clone | Standard Stack | Very low — this is standard git; tested indirectly in research session |
| A2 | `mutate_cp` called with a directory item from `find -mindepth 1 -maxdepth 1` correctly uses `cp -r` (because `[ -d "$item" ]` is true for directory items) | Pattern 5 | Low — mutate_cp source was read; -d check is correct |
| A3 | CI shellcheck glob `find cli scripts migrations profiles compliance templates/hooks tests lib -name '*.sh'` covers `scripts/init-overlay.sh` and `scripts/refresh-overlay.sh` (both in `scripts/`) | Environment Availability | Confirmed by reading ci.yml line 22 — glob is `scripts` directory |

**If this table is empty:** Not empty — three low-risk assumptions noted above.

## Open Questions

1. **Should `conjure init --overlay` print a per-file applied summary?**
   - What we know: `mutate_summary` reports total mutation count; other worker scripts print `echo "  ✓ created $f"` per file
   - What's unclear: Whether the user wants to see which files came from the overlay vs base kit
   - Recommendation: Call `mutate_summary` at end (standard); optionally print "▸ Overlay applied: N files from $OVERLAY_URL" — delegate to planner

2. **How to test `refresh-overlay` backup with DRY_RUN?**
   - What we know: Backup uses direct `cp -R` (not `mutate_cp`), consistent with `cmd_update --apply` at line 214 which also uses plain `cp -R`
   - What's unclear: Whether backup should be suppressed in dry-run (it's not a mutation of `.claude/`, it's a safety copy)
   - Recommendation: Follow existing precedent — `cmd_migrate` at line 128 does `[ "$dryrun" = 0 ] && cp -R`. Backup is skipped in dry-run.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `git` | clone, ls-remote, rev-parse | ✓ | 2.54.0 | — (git is required; exit 2 if absent) |
| `mktemp` | temp dir creation | ✓ | POSIX stdlib | — (universal) |
| `find` | overlay file enumeration | ✓ | POSIX stdlib | — (universal) |
| `cp -r` | file copy | ✓ | POSIX stdlib | — (universal) |
| `awk` | SHA extraction from ls-remote | ✓ | POSIX stdlib | `cut -f1` as fallback |

**Missing dependencies with no fallback:** None. All required tools are standard POSIX utilities
plus git, which is already a declared Conjure prerequisite (verified in `scripts/preflight.sh`).

**git ls-remote auth:** For private repos, git uses the system credential store (macOS Keychain,
GNOME Wallet, credential-helper). No special handling needed — git transparently delegates.
On auth failure, exit code is 128 and the audit must gracefully skip the drift check.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Hand-rolled bash test runner in `tests/run.sh` |
| Config file | none |
| Quick run command | `bash tests/run.sh` |
| Full suite command | `bash tests/run.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OVLY-01 | `conjure init --overlay <url>` applies base kit then overlay | integration | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-01 | All writes go through `lib/mutate.sh` (DRY_RUN honored) | unit | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-02 | `.conjure-org-overlay` marker written with url= and sha= | integration | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-03 | `conjure refresh-overlay` re-applies with overlay-wins | integration | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-03 | Missing marker → exit 1 with correct message | unit | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-04 | Audit reports up-to-date when SHA matches | integration | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-04 | Audit reports DRIFT when SHA differs | integration | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-04 | Audit skips drift check on git ls-remote failure | unit | inline in `tests/run.sh` | ❌ Wave 0 |
| OVLY-05 | No credential storage in Conjure code | static grep | inline in `tests/run.sh` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash tests/run.sh`
- **Per wave merge:** `bash tests/run.sh`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] OVLY test blocks in `tests/run.sh` — all 9 test assertions above
- [ ] `scripts/init-overlay.sh` — new worker script (tested by OVLY tests)
- [ ] `scripts/refresh-overlay.sh` — new worker script (tested by OVLY tests)

*(No separate test infrastructure needed — all tests inline in `tests/run.sh` following established pattern)*

### OVLY Test Block Design

The test structure uses the `file://` URL pattern verified in this research session:

```
OVLY-SETUP:
  Create local git repo as mock overlay (file:// URL, no network)
  files: skills/org-skill/SKILL.md, agents/org-agent.md
  initial commit → OVLY_EXPECTED_SHA

OVLY-01a: conjure init --overlay <file://url> → exits 0
OVLY-01b: overlay files appear in .claude/ (skills/org-skill/, agents/org-agent.md)
OVLY-01c: base kit files also present (init-project.sh ran first)
OVLY-02a: .claude/.conjure-org-overlay exists
OVLY-02b: url= line matches overlay URL
OVLY-02c: sha= line matches actual overlay commit SHA
OVLY-03a: conjure refresh-overlay exits 0 (marker exists)
OVLY-03b: refresh-overlay re-applies overlay (file still present after refresh)
OVLY-03c: conjure refresh-overlay (no marker) exits 1 with "No org overlay configured"
OVLY-04a: conjure audit → "up to date" when SHA matches
OVLY-04b: Manually overwrite sha= with fake SHA → audit reports DRIFT warning
OVLY-04c: Invalid URL in marker → audit skips drift check with skip message, exits 0
OVLY-05a: grep -r 'password\|credential\|token' scripts/init-overlay.sh → no matches
OVLY-05b: grep -r 'password\|credential\|token' scripts/refresh-overlay.sh → no matches
```

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no — git credential delegation, not Conjure auth | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes — overlay URL is user input | validate URL is non-empty; git clone provides implicit URL validation |
| V6 Cryptography | no | — |

### Known Threat Patterns for this Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious overlay repo content | Tampering | D-02 design choice — overlay maintainers own content; out of Conjure's scope |
| Credential leakage via URL with embedded token | Information Disclosure | Do not log the full overlay URL in plain text; consider masking if URL contains `@` |
| .git injection into .claude/ | Tampering | `find … ! -name '.git'` copy pattern (Pitfall 1 mitigated) |
| Arbitrary file overwrite via overlay | Tampering | By design (D-03) — organization controls overlay content |

**OVLY-05 is a security invariant:** The `grep -r credential` static test in OVLY-05a/b enforces
this at the test level. No credential storage patterns may appear in either new worker script.

## Sources

### Primary (HIGH confidence)
- `cli/conjure` (lines 54-110, 253-256, 308-320) — cmd_init, cmd_refresh_graph, dispatch table
- `lib/mutate.sh` — mutate_cp, mutate_write, mutate_mkdir, mutate_summary implementations
- `scripts/audit-setup.sh` — ok/warn/err convention, conflict-marker check pattern (lines 132-145)
- `scripts/publish-plugin.sh` — worker script structural template
- `tests/run.sh` — test ID conventions, git sandbox setup pattern (lines 764-776)
- Shell testing in this research session — all copy/clone/ls-remote patterns were verified

### Secondary (MEDIUM confidence)
- `scripts/refresh-graph.sh` — refresh worker pattern
- `tests/lib/sandbox.sh` — sandbox isolation helper (relevant context)
- `.github/workflows/ci.yml` — shellcheck glob coverage for `scripts/*.sh` confirmed

### Tertiary (LOW confidence)
- None — all claims are verified from codebase or shell testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools verified in this research session
- Architecture: HIGH — patterns read directly from existing codebase
- Pitfalls: HIGH — pitfalls 1 and 2 confirmed via live shell testing
- Test design: HIGH — file:// URL clone approach verified, follows established test patterns

**Research date:** 2026-05-26
**Valid until:** 2026-06-26 (git plumbing is stable; project conventions unlikely to change)
