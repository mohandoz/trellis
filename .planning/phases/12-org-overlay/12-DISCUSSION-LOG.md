# Phase 12: Org Overlay - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-26
**Phase:** 12-org-overlay
**Areas discussed:** Overlay repo structure, Refresh semantics, Drift detection in audit, Clone strategy & lifecycle

---

## Overlay Repo Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror .claude/ | Overlay repo root maps directly to .claude/. No manifest needed. | ✓ |
| Subdirectory (overlay/) | Overlay repo has an overlay/ subdir mapping to .claude/. Allows non-Claude files in repo. | |
| Manifest-driven (overlay.json) | Explicit file list with rules and targets. Max control, more complexity. | |

**User's choice:** Mirror .claude/

| Option | Description | Selected |
|--------|-------------|----------|
| All files, no exclusions | Every file in overlay repo root applied to .claude/. | ✓ |
| Skip .conjure-* and settings.json | Exclude Conjure-internal files from overlay application. | |
| Allowlist in overlay.json | Only explicitly listed files applied. | |

**User's choice:** All files, no exclusions

**Notes:** Simplest possible rule. Overlay repo maintainers are responsible for content.

---

## Refresh Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Overlay always wins | Overlay unconditionally overwrites user edits. Backup-before-mutate is safety net. | ✓ |
| 3-way merge via lib/merge.sh | User edits preserved via merge; conflicts become sidecars. | |

**User's choice:** Overlay always wins

| Option | Description | Selected |
|--------|-------------|----------|
| Exit 1 with clear message | "No org overlay configured. Run conjure init --overlay first." | ✓ |
| Silently succeed | Do nothing if no overlay configured. | |

**User's choice:** Exit 1 with clear message

**Notes:** Overlay-wins is the org-control model. Backup-before-mutate provides recovery. No-marker = fail loudly.

---

## Drift Detection in Audit

| Option | Description | Selected |
|--------|-------------|----------|
| git ls-remote vs pinned SHA | Network check; reports URL, pinned SHA, upstream SHA, DRIFT if differ. | ✓ |
| Local-only (report pinned SHA) | No network. Just print URL + SHA from marker file. | |

**User's choice:** git ls-remote to compare pinned SHA vs upstream HEAD

| Option | Description | Selected |
|--------|-------------|----------|
| Warn and continue | Print skip notice; audit exits 0. Network issues don't block CI. | ✓ |
| Fail audit | Exit non-zero if drift check can't complete. | |

**User's choice:** Warn and continue — don't fail audit

**Notes:** Network failures (private repos, offline CI) must not block audit. Drift is informational.

---

## Clone Strategy & Lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| Temp dir, cleaned after apply | mktemp -d; clone; copy files; rm -rf. No persistent clone. | ✓ |
| Persistent cache (.claude/.conjure-overlay-cache/) | git pull on refresh; faster but nested .git under .claude/. | |

**User's choice:** Temp dir, cleaned up after apply

| Option | Description | Selected |
|--------|-------------|----------|
| Shallow --depth 1 | Faster, smaller. Only current HEAD content needed. | ✓ |
| Full clone | Needed if overlay uses git history/tags/branches. Unlikely. | |

**User's choice:** Shallow clone --depth 1

**Notes:** Clean working tree is the priority. No persistent git metadata. Shallow is sufficient for content-only apply.

---

## Claude's Discretion

- Function naming inside worker scripts
- Whether overlay logic lives in new scripts or extends cmd_init path (researcher decides)
- Exact marker file format (.conjure-org-overlay: JSON vs flat key=value)
- Test IDs for OVLY regression tests
- Post-install summary format (consistent with mutate_summary pattern)

## Deferred Ideas

- `compatible-kit-version` manifest field — deferred to v0.4.x
- Persistent overlay cache for faster refresh — deferred; optimize if latency is a real complaint
- `--dry-run` flag for `conjure init --overlay` — deferred; DRY_RUN env still honored through mutate.sh
