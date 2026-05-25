# Phase 12: Org Overlay - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement `conjure init --overlay <git-url>` + `conjure refresh-overlay` + overlay
audit reporting so an organization can maintain a private git repo of `.claude/`
customizations that are applied on top of the base Conjure kit.

Delivers:
- `scripts/init-overlay.sh` worker (or extended `cmd_init` path) — applies base kit,
  then clones overlay repo and copies files into `.claude/`; all writes via `lib/mutate.sh`
- `scripts/refresh-overlay.sh` worker — re-clones overlay from marker URL and re-applies;
  overlay-wins semantics; backup-before-mutate
- `.claude/.conjure-org-overlay` marker file: records overlay URL + cloned commit SHA
- `conjure audit` overlay section: reports overlay presence, pinned SHA, upstream HEAD SHA
  (via `git ls-remote`), and DRIFT status if they differ
- `cmd_refresh_overlay` dispatcher in `cli/conjure`
- OVLY regression tests in `tests/run.sh`

Does NOT introduce Homebrew (Phase 13), Docker (Phase 14), release pipeline (Phase 15),
or overlay version compatibility contracts (deferred to v0.4.x).

</domain>

<decisions>
## Implementation Decisions

### Overlay Repo Structure (OVLY-01)
- **D-01:** Overlay repo root maps directly to `.claude/`. A file at `skills/foo/SKILL.md`
  in the overlay repo is applied to `.claude/skills/foo/SKILL.md` in the target project.
  No subdirectory wrapper, no `overlay.json` manifest required.
- **D-02:** All files in the overlay repo are applied — no exclusions. Overlay repo
  maintainers are responsible for the content. Simplest possible rule: overlay repo is
  a mirror of `.claude/`.

### Refresh Semantics (OVLY-03)
- **D-03:** Overlay always wins — overlay files unconditionally overwrite existing `.claude/`
  files on `refresh-overlay`. User edits to overlay-managed files are overwritten. Backup-
  before-mutate runs first so no data is permanently lost, but the semantic is clear:
  org-controlled files stay org-controlled.
- **D-04:** `conjure refresh-overlay` exits 1 with message `"No org overlay configured.
  Run conjure init --overlay <git-url> first."` if no `.conjure-org-overlay` marker file
  exists. Prevents silent no-ops.

### Drift Detection in Audit (OVLY-04)
- **D-05:** `conjure audit` runs `git ls-remote <overlay-url>` to get the current remote
  HEAD SHA and compares it against the pinned SHA in `.conjure-org-overlay`. Reports:
  overlay URL, pinned SHA, upstream SHA, and `DRIFT` warning if they differ.
- **D-06:** If `git ls-remote` fails (no network, private repo auth failure, etc.), audit
  prints `[overlay] drift check skipped (git ls-remote failed)` and continues. Audit still
  exits 0 — network failures must not block CI audit runs.

### Clone Strategy & Lifecycle (OVLY-01, OVLY-03, OVLY-05)
- **D-07:** Clone into a `mktemp -d` temp directory. After copying all files into `.claude/`,
  `rm -rf` the temp dir. No persistent local clone stored in the project. Clean working tree,
  no nested `.git` metadata under `.claude/`.
- **D-08:** Use `git clone --depth 1 <url>` (shallow clone). Only current HEAD content is
  needed; full history is waste. Faster for large org repos.
- **D-09:** Authentication uses the user's existing git credential store. No credentials
  are stored by Conjure (OVLY-05 invariant).

### Claude's Discretion
- Function naming inside `scripts/init-overlay.sh` and `scripts/refresh-overlay.sh`
- Whether overlay logic lives in a new script or inside the existing `cmd_init` path in
  `cli/conjure` (researcher to decide based on script size vs. dispatch consistency)
- Exact marker file format for `.conjure-org-overlay` (researcher resolves — JSON vs. flat
  `url\nsha` — consistent with other marker files like `.conjure-version`)
- Test IDs for OVLY regression tests (OVLY-NN blocks in `tests/run.sh`)
- Whether `conjure init --overlay` also prints a post-install summary showing which overlay
  files were applied (researcher: consistent with `mutate_summary` pattern)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and success criteria
- `.planning/REQUIREMENTS.md` §"Org Overlay (DIST-05)"
  — OVLY-01 through OVLY-05, the five locked requirements
- `.planning/ROADMAP.md` §"Phase 12: Org Overlay"
  — success criteria (5 items) and phase goal

### Existing code to read before implementing
- `cli/conjure` lines 54-106 — `cmd_init()`: arg-parsing pattern to extend with `--overlay` flag;
  backup, mutate.sh sourcing, profile overlay pattern at line 82
- `cli/conjure` lines 253-256 — `cmd_refresh_graph()`: model for `cmd_refresh_overlay` dispatcher
  (thin shell → worker script)
- `cli/conjure` lines 308-320 — dispatch table; `refresh-overlay)` case slots here
- `scripts/publish-plugin.sh` — structural template for new worker scripts: arg-parsing,
  mutate.sh sourcing, exit code conventions, `DRY_RUN` env pattern
- `lib/mutate.sh` — all filesystem writes MUST route through `mutate_write`/`mutate_cp`/`mutate_mkdir`
- `scripts/audit-setup.sh` lines 132-143 — existing audit check pattern (conflict markers);
  overlay section follows the same `ok`/`note`/`fail` convention
- `tests/run.sh` — existing test ID conventions before writing OVLY-NN blocks

### Write chokepoint (invariant)
- `lib/mutate.sh` — all new writes go through `mutate_write`/`mutate_cp`/`mutate_mkdir`
- `DRY_RUN` env var — all mutation paths check this before writing (checked via `${DRY_RUN:-0}`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cmd_init()` arg-parsing loop at `cli/conjure:54` — extend with `--overlay=*` case; same
  pattern as `--profile=*`
- `lib/mutate.sh` — `mutate_cp` handles directory copies with `cp -r`; use directly to apply
  overlay files into `.claude/`
- Backup-before-mutate pattern from `cmd_migrate` / `cmd_update` — copy exact idiom for
  `refresh-overlay` before overwriting
- `scripts/refresh-graph.sh` — model for a standalone `scripts/refresh-overlay.sh` worker
- `cmd_refresh_graph()` at `cli/conjure:253` — 3-line dispatcher pattern; `cmd_refresh_overlay`
  follows same shape

### Established Patterns
- `--dry-run` → `DRY_RUN=1`; all mutation paths check this via `mutate_*` functions (transparent)
- Exit 1 for user-fixable errors (missing marker, bad URL); exit 2 for hard prereq failures
  (missing git, missing `lib/mutate.sh`)
- All new shell scripts must be shellcheck-clean; added to shellcheck glob in `.github/workflows/ci.yml`
- Tests inline in `tests/run.sh` with block IDs (e.g., `OVLY-01` through `OVLY-05`)
- `mutate_summary` called at end of each worker script to report mutation count

### Integration Points
- `cli/conjure` dispatch table at line ~318 — add `refresh-overlay)` case
- `cmd_init()` arg parser at line ~58 — add `--overlay=*` case alongside `--profile=*`
- `scripts/audit-setup.sh` — add overlay presence + drift check section after existing checks
- `ci.yml` shellcheck glob — confirm it covers `scripts/*.sh` (add new scripts if glob is explicit)

</code_context>

<specifics>
## Specific Ideas

- Overlay repo layout: pure `.claude/` mirror — no manifest, no subdirectory. Dead simple.
- Clone: `git clone --depth 1 <url> <tmpdir>` → copy → `rm -rf <tmpdir>`. No persistent clone.
- Drift check: `git ls-remote` is the chosen mechanism; graceful degradation on failure (warn, don't fail).
- `refresh-overlay` without marker = exit 1 with explicit error message. No silent no-op.
- Overlay-wins = unconditional overwrite on refresh. Backup-before-mutate is the safety net.

</specifics>

<deferred>
## Deferred Ideas

- `compatible-kit-version` manifest field in overlay repo (version compatibility contract) —
  deferred to v0.4.x per STATE.md; define before first production overlay ships
- Persistent overlay cache under `.claude/` for faster refresh — deferred; temp-dir approach
  ships first; cache optimization is a v0.4.x concern if refresh latency is a real complaint
- `--dry-run` support for `conjure init --overlay` — deferred per REQUIREMENTS.md Future section;
  `DRY_RUN` env still honored through `lib/mutate.sh` but no explicit `--dry-run` flag in Phase 12

</deferred>

---

*Phase: 12-org-overlay*
*Context gathered: 2026-05-26*
