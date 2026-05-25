---
phase: 1
slug: pre-flight-cross-platform-hooks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-24
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Hand-rolled bash (`tests/run.sh`) — project standard |
| **Config file** | none — `tests/run.sh` is self-contained |
| **Quick run command** | `bash tests/run.sh` |
| **Full suite command** | `bash tests/run.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/run.sh`
- **After every plan wave:** Run `bash tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | SAFE-04 | — | preflight.sh exits 0 when all deps present | smoke | `bash tests/run.sh` | ❌ Wave 0 | ⬜ pending |
| 1-01-02 | 01 | 1 | SAFE-04 | — | preflight.sh exits non-zero when `node` missing | unit | `bash tests/run.sh` | ❌ Wave 0 | ⬜ pending |
| 1-01-03 | 01 | 1 | SAFE-04 | — | preflight.sh exits 0 when only optional dep missing | unit | `bash tests/run.sh` | ❌ Wave 0 | ⬜ pending |
| 1-01-04 | 01 | 1 | SAFE-04 | — | fix-it output contains OS-specific package manager name | output | `bash tests/run.sh` | ❌ Wave 0 | ⬜ pending |
| 1-02-01 | 02 | 1 | SAFE-03 | — | settings.json.tmpl contains no `bash .claude/hooks/` strings | lint | `bash tests/run.sh` | ❌ Wave 0 | ⬜ pending |
| 1-02-02 | 02 | 1 | SAFE-03 | — | settings.json.tmpl contains `node .claude/hooks/` strings | lint | `bash tests/run.sh` | ❌ Wave 0 | ⬜ pending |
| 1-02-03 | 02 | 1 | SAFE-03 | — | scripts/preflight.sh is executable (found by existing test loop) | existing | `bash tests/run.sh` | ✅ auto-covered | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/preflight.sh` — must be created in Wave 1 (task 01); Wave 0 here means Wave 1 creates the file before tests run against it
- [ ] `tests/run.sh` preflight section — add after the existing audit-script self-test block
- [ ] Template lint assertions in `tests/run.sh` — grep that `templates/settings.json.tmpl` contains `node .claude/hooks/` and does NOT contain `bash .claude/hooks/`

*Note: This phase uses the hand-rolled `tests/run.sh` rather than a dedicated test framework. "Wave 0" in this context means the test sections are added within the same wave as the feature they cover (Wave 1), not as a separate preceding wave.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hooks fire on native Windows after `conjure init` | SAFE-03 | Requires a Windows machine or CI (not available in dev loop) | Run `conjure init` on native Windows (no Git Bash), open Claude Code — verify hooks execute without "bash not found" error |
| Fix-it lines show correct winget package IDs | SAFE-04 | winget package IDs assumed [LOW confidence in RESEARCH]; need registry verification | On Windows, run `conjure preflight` with node missing; verify `winget install OpenJS.NodeJS` appears and executes correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
