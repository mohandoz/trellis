---
phase: 5
slug: readme-demo
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (tests/run.sh) |
| **Config file** | tests/run.sh |
| **Quick run command** | `bash tests/run.sh` |
| **Full suite command** | `bash tests/run.sh` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/run.sh`
- **After every plan wave:** Run `bash tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | DOCS-01 | — | record-demo.sh uses mktemp -d; no writes outside temp dir | manual | `bash scripts/record-demo.sh && test -s .github/assets/demo.gif` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | DOCS-01 | — | N/A | integration | `grep -q demo.gif README.md` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 2 | DOCS-01 | — | N/A | integration | `test -s .github/assets/demo.gif` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.github/assets/` directory exists — `test -d .github/assets`
- [ ] `scripts/record-demo.sh` stub or full implementation

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GIF renders correctly in browser/GitHub | DOCS-01 | Visual verification required | Open .github/assets/demo.gif; confirm animation plays, text is readable, sequence shows init→audit |
| Recording runs under 60 seconds | DOCS-01 | Timing requires human review | Run `bash scripts/record-demo.sh`; confirm total duration ≤60s |
| asciinema/agg/expect present on system | DOCS-01 | Toolchain install; not in CI | Run preflight check in record-demo.sh; install missing tools before re-recording |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
