---
phase: 6
slug: cost-estimator
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (hand-rolled tests/run.sh) |
| **Config file** | none — existing framework |
| **Quick run command** | `bash tests/run.sh --filter cost` |
| **Full suite command** | `bash tests/run.sh` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/run.sh --filter cost`
- **After every plan wave:** Run `bash tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | COST-01 | — | chars/4 heuristic, no network | unit | `bash tests/run.sh --filter cost` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 1 | COST-02 | — | ±20% band in output | unit | `bash tests/run.sh --filter cost` | ❌ W0 | ⬜ pending |
| 6-01-03 | 01 | 2 | COST-03 | — | --exact fallback when no API key | unit | `bash tests/run.sh --filter cost` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/fixtures/cost/` — test fixture directory for cost output
- [ ] `tests/run.sh --filter cost` — filter support or new test function

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `--exact` calls `countTokens` API | COST-03 | Requires live ANTHROPIC_API_KEY | Set key, run `conjure audit --cost --exact .`, verify exact token count in output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
