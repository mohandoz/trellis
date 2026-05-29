---
phase: 23-restructure-skill-safety-gates
verified: 2026-05-29T02:45:07Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
manual_verification_performed: 2026-05-29
manual_verification_method: "Interactive approve/skip/edit loop driven through a real PTY via `expect` (genuine /dev/tty read, not the CONJURE_FORCE_INTERACTIVE shortcut). 13/13 assertions passed — including a live confirmation of the CR-01 fix."
re_verification:
  previous_status: none
  note: "Initial verification — no prior VERIFICATION.md existed"
human_verification:
  - test: "In a real terminal, run the restructure skill against a brownfield repo and exercise the per-class /dev/tty approve / skip / edit loop"
    expected: "Each non-empty classification bucket presents ONE prompt; 'approve' applies the bucket's non-archive steps via conjure adopt --apply-step; 'skip' leaves files as-is; 'edit' re-drafts + re-runs GATE A + GATE B before re-prompting; the loop NEVER proceeds without an explicit a/s/e response; archive candidates are confirmed individually in the archive-last pass"
    result: "VERIFIED 2026-05-29 via PTY (expect), 13/13 checks. non-TTY → exit 2 (D-12). core bucket: bad input re-prompts (D-14 no default), [a]pprove applied step-1 (write CLAUDE.md from staging), ONE RESTRUCTURE summary line (D-09). reference-doc bucket: [a]pprove did NOT apply step-2 (op:archive) — it stayed `proposed` and docs/OLD.md was NOT archived (CR-01 fix confirmed live; archive deferred to the archive-last pass per D-15/D-11). [e]dit printed re-draft guidance + gate-rerun, no $EDITOR launch, re-prompted (O-3/D-10)."
    why_human: "The interactive /dev/tty read loop can only be driven from a PTY. Verified by driving a real pseudo-terminal with `expect` rather than the non-interactive harness."
---

# Phase 23: Restructure Skill + Safety Gates Verification Report

**Phase Goal:** The human-gated restructure skill is installed and operational, with pre-write safety gates that block invalid LLM proposals before the user is ever asked to approve them.
**Verified:** 2026-05-29T02:45:07Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | After `conjure adopt`, `restructure` skill present at `.claude/skills/restructure/SKILL.md`; frontmatter `allowed-tools: [Read, Bash]`; ≤200 lines | ✓ VERIFIED | `templates/skills/restructure/SKILL.md` is 121 lines, line 4 `allowed-tools: [Read, Bash]`, line 5 `disallowed-tools: [Write, Edit]`. `scripts/init-project.sh:59` scaffold loop includes `restructure` (whole-dir `mutate_cp` → gates land too). tests/run.sh:3074-3093 scaffolds into a sandbox target and asserts SKILL.md present, frontmatter, ≤200 lines, gates ship alongside — all 4 PASS. |
| 2 | Skill reads manifest, proposes numbered plan, requires explicit approve/skip/edit per step, never proceeds without response, never Write/Edit on project files | ◐ VERIFIED (auto) + HUMAN (interactive) | SKILL.md step sequence (lines 44-78) narrates read-manifest → propose via `conjure adopt --update-manifest` → never Write/Edit (RESTR-02 hard rule lines 16-31, 98-114). `approve.sh` implements approve/skip/edit verbs (lines 125-197) with no auto-proceed on empty/unknown (lines 193-196). Non-TTY exit-2 guard (approve.sh:34) AUTOMATED + PASSES (tests/run.sh:3190). The live /dev/tty interactive loop requires human/PTY → see Human Verification. |
| 3 | 50+ files: per-class grouped approvals (not per-file); RESTRUCTURE-LOG.md records only a summary line for bulk ops | ✓ VERIFIED | `approve.sh:106` groups over 6 non-archive buckets; `approve.sh:113-116` prints bucket header + first-5 preview ("… and N more"), ONE prompt per bucket; `log_step RESTRUCTURE` emits ONE summary line per bucket (lines 121, 173, 178). tests/run.sh:3217 asserts ≥1 RESTRUCTURE summary line — PASS. |
| 4 | Constraint-extraction → INVARIANTS; condensed CLAUDE.md omitting an invariant BLOCKS with missing invariants BEFORE user sees proposal | ✓ VERIFIED | `extract-invariants.sh` greps canonical-token signals → `INVARIANTS.candidates` under `.conjure-adopt-state/` only (path-traversal refused, lines 36-62). `verify-invariants.sh` (GATE A) normalized-substring check → `exit 2` + missing list on drop (lines 59-70). SKILL.md step 4 runs GATE A BEFORE step 5 approval. tests/run.sh:2948-2974 (present→0, missing→2+list, reflowed→0) + 3045-3058 (extract) — 6 PASS. |
| 5 | Proposed CLAUDE.md with @import run through conjure audit before approval; gate BLOCKS with audit output, no prompt | ✓ VERIFIED | `audit-staged.sh` (GATE B) stages file as CLAUDE.md in a temp dir, runs the REAL `scripts/audit-setup.sh` (line 52) to surface WHY, blocks on `^@` @import (line 56) and `> CLAUDE_MD_CAP=100` (lines 64-65) → `exit 2`. SKILL.md step 4 runs GATE B BEFORE approval. tests/run.sh:2984-3005 (@import→2, clean→0, oversized→2) — 3 PASS. |
| 6 | Archive steps last; decision-vocabulary keywords flagged for individual confirmation, not bulk archive | ✓ VERIFIED | SKILL.md step 6 (lines 74-78) sequences archive LAST + routes each candidate through `decision-scan.sh`. `decision-scan.sh:30` scans `decided/we chose/rationale/\bdo not\b/\bnever\b` → `individual` vs `bulk`. CR-01 fix in `approve.sh:150-156` (`select(.op != "archive")` + `select(.status=="proposed")`) ensures archive NEVER fires during a non-archive bucket. tests/run.sh:3016-3026 (decision→individual, clean→bulk) + 3165-3173 (archive-last order) + 3260-3272 (CR-01 regression ×2) — 5 PASS. |

**Score:** 6/6 truths verified. Criterion 2's interactive /dev/tty approve/skip/edit loop is the only sub-check requiring human/PTY validation; its non-TTY exit-2 half is automated and passes.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `templates/skills/restructure/SKILL.md` | Orchestration runbook, ≤200 lines, `allowed-tools: [Read, Bash]` | ✓ VERIFIED | 121 lines; frontmatter correct; full step sequence + gate catalog + forbidden actions |
| `templates/skills/restructure/gates/verify-invariants.sh` | GATE A normalized-substring invariant verifier | ✓ VERIFIED | exit 2 on drop/bad args; normalize() lowercase+collapse; missing list on stderr |
| `templates/skills/restructure/gates/audit-staged.sh` | GATE B @import/cap-breach via real conjure audit shim | ✓ VERIFIED | temp-dir shim → `audit-setup.sh`; blocks @import + >CAP; exit 2; sources lib/caps.sh |
| `templates/skills/restructure/gates/extract-invariants.sh` | Constraint-extraction pre-pass under `.conjure-adopt-state/` | ✓ VERIFIED | greps canonical tokens; `..` traversal + non-state-dir writes refused; exit 2 on error |
| `templates/skills/restructure/gates/decision-scan.sh` | Decision-vocabulary scan → individual/bulk | ✓ VERIFIED | 5 D-11 terms with word-boundaries; stdout token + stderr match lines; read-only |
| `templates/skills/restructure/gates/approve.sh` | Per-class /dev/tty approve/skip/edit + non-TTY exit-2 + bulk summary | ✓ VERIFIED | non-TTY guard line 34; CR-01 archive-exclusion; IN-02 failed counter; one log line/bucket |
| `scripts/init-project.sh` (scaffold edit) | Scaffolds restructure into target `.claude/skills/` | ✓ VERIFIED | line 59 loop includes `restructure`; IN-01 fix `exit 2` (line 17, no exit 1) |
| `tests/run.sh` (Phase 23 block) | Real assertions for all 6 criteria + CR-01 regression | ✓ VERIFIED | lines 2917-3280; 23 Phase-23 assertions all green; CR-01 regression ×2 |
| `tests/fixtures/_restructure-gates/*` | 8 synthetic gate fixtures | ✓ VERIFIED | INVARIANTS.txt + with/missing/reflowed-invariant, with-import, oversized, decision-doc, clean-doc |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `scripts/init-project.sh` | `templates/skills/restructure/` | line-59 scaffold loop (`mutate_cp` whole dir) | ✓ WIRED | Sandbox scaffold test confirms SKILL.md + gates land in target `.claude/skills/restructure/` |
| `SKILL.md` | `conjure adopt --update-manifest / --apply-step` | Bash invocation of Phase 22 seam (stdin op JSON), never Write/Edit | ✓ WIRED | SKILL.md steps 3-6 + hard rule; apply-step routing test (tests/run.sh:3116-3126) confirms `status: applied` + dest mutated through mutate.sh |
| `approve.sh` | `/dev/tty` | `read -r ... < /dev/tty` with `[ -t 0 ]` non-TTY exit-2 guard | ✓ WIRED (non-TTY half) | approve.sh:83-101, 34; non-TTY exit-2 test PASS. Live /dev/tty read → human verification |
| `audit-staged.sh` | `scripts/audit-setup.sh` | temp-dir shim seeds staged file as CLAUDE.md → real conjure audit | ✓ WIRED | audit-staged.sh:45-52; audit-setup.sh present + executable; lib/caps.sh supplies CLAUDE_MD_CAP=100 |
| `verify-invariants.sh` | `.conjure-adopt-state/INVARIANTS.txt` | reads LLM-confirmed token list as needle set | ✓ WIRED | verify-invariants.sh:37-57 reads the file arg; INVARIANTS.txt fixture drives the GATE A tests |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Full test suite green | `bash tests/run.sh` | `PASS: 429    FAIL: 0` | ✓ PASS |
| Shellcheck CI gate on changed scripts | `shellcheck -S error -e SC2164,SC2044,SC2034,SC2155 gates/*.sh init-project.sh check.sh` | exit 0 | ✓ PASS |
| GATE A blocks dropped invariant | `bash verify-invariants.sh missing-invariant.md INVARIANTS.txt` | exit 2 + missing list | ✓ PASS |
| GATE B blocks @import | `bash audit-staged.sh with-import.md` | exit 2 | ✓ PASS |
| GATE B blocks oversized | `bash audit-staged.sh oversized.md` | exit 2 (cap breach) | ✓ PASS |
| decision-scan escalates decision doc | `bash decision-scan.sh decision-doc.md` | "individual" | ✓ PASS |
| approve.sh non-TTY guard | `bash approve.sh target < /dev/null` | exit 2 (no auto-approve) | ✓ PASS |
| CR-01 fix has real teeth (regression value check) | drove CR-01 scenario against a reconstructed PRE-FIX approve.sh (line `select(.op != "archive")` removed) | PRE-FIX: step-2 archive applied + `docs/OLD.md` MOVED into `.conjure-archive-*`. SHIPPED: step-2 stays `proposed`, OLD.md untouched | ✓ PASS (regression genuinely catches the bug) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| RESTR-01 | 23-01, 23-03 | restructure skill reads manifest + proposes plan | ✓ SATISFIED | SKILL.md inputs/step-1 + group-by tests; REQUIREMENTS.md:46/98 Complete |
| RESTR-02 | 23-01, 23-03 | skill applies changes ONLY via conjure adopt (Read+Bash only) | ✓ SATISFIED | allowed-tools [Read,Bash]; apply-step routing test; hard rule + forbidden actions; REQUIREMENTS.md:47/99 |
| RESTR-03 | 23-01, 23-03 | per-step approval, per-class grouped at scale | ✓ SATISFIED (◐ interactive→human) | approve.sh 6-bucket grouping + summary log; non-TTY exit-2 auto; live loop→human; REQUIREMENTS.md:48/100 |
| RESTR-04 | 23-01, 23-02 | constraint-extraction + invariant verification blocks if missing | ✓ SATISFIED | extract-invariants + verify-invariants (GATE A) tests; REQUIREMENTS.md:49/101 |
| RESTR-05 | 23-01, 23-02 | proposed content run through conjure audit, block @import/cap pre-write | ✓ SATISFIED | audit-staged (GATE B) tests; real audit-setup.sh shim; REQUIREMENTS.md:50/102 |
| RESTR-06 | 23-01, 23-02 | archive last, individually confirmed, decision-vocabulary gated | ✓ SATISFIED | decision-scan + archive-last + CR-01 regression tests; REQUIREMENTS.md:51/103 |

All 6 declared requirement IDs are present in REQUIREMENTS.md (lines 46-51) AND mapped to Phase 23 in the traceability table (lines 98-103). No orphaned requirements: every RESTR-0x in REQUIREMENTS.md mapped to Phase 23 appears in a Phase 23 plan's `requirements` field. No additional Phase 23 IDs unclaimed by plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | — | No TBD/FIXME/XXX in any Phase 23 file | — | — |
| (none) | — | No `exit 1` in any shipped script (project convention `exit 2` honored; IN-01 fixed) | — | — |
| (none) | — | All `Write`/`Edit` references in SKILL.md are forbidden/disallowed-context only (frontmatter + hard rule) | — | — |

One Info-level finding was deliberately accepted without code change (IN-03: approve.sh leaks two `mktemp` temp files in `$TMPDIR` if `--apply-step` aborts mid-bucket). Documented in 23-REVIEW-FIX.md as a bounded, future-hardening item — not a goal blocker.

### Review-Fix Confirmation

All 7 fixed review findings confirmed present in the shipped code; all 4 fix commits exist:

| Finding | Fix in codebase | Commit (verified present) |
| ------- | --------------- | ------------------------- |
| CR-01 (Critical) | approve.sh:150-156 `select(.op != "archive")` + `select(.status=="proposed")`; regression tests/run.sh:3227-3276 | 9f92ea6 |
| WR-01 | SKILL.md:26-30 corrected env-var-wins-over-stdin doc + unset guidance | 10e49f4 |
| WR-02 | approve.sh:31-37 TEST-ONLY comment + SKILL.md:111-113 forbidden action | 10e49f4 |
| WR-03 | verify-invariants.sh:12-22 KNOWN-LIMITATION (substring + polarity blindness) | 07b0930 |
| IN-01 | init-project.sh:17 `exit 2` (was exit 1) | bdfd2de |
| IN-02 | approve.sh:130 `failed` counter surfaced in summary line 173 + screen 174 | bdfd2de |
| IN-04 | check.sh:110 `grep -qxF` (whole-line anchored) | bdfd2de |

### Human Verification Required

#### 1. Interactive per-class approve / skip / edit loop (criterion 2 / RESTR-03)

**Test:** In a real terminal, invoke the restructure skill against a brownfield repo (or run `gates/approve.sh <target>` directly with a TTY) and exercise the per-class approval loop across multiple buckets.
**Expected:** Each non-empty classification bucket presents exactly ONE `/dev/tty` prompt (`[a]pprove / [s]kip / [e]dit`). `approve` applies the bucket's non-archive steps through `conjure adopt --apply-step` and logs one summary line. `skip` leaves files as-is. `edit` re-drafts staged content and re-runs GATE A + GATE B before re-prompting. The loop NEVER advances without an explicit a/s/e (unknown input re-prompts). Archive candidates are confirmed individually in the archive-last pass.
**Why human:** The interactive `/dev/tty` read loop and verb routing can only be driven from a PTY by a human. The non-TTY half (exit 2, never auto-approve) IS automated and PASSES; only the live interactive UX is human-gated — mirrors the Phase 22 precedent.

### Gaps Summary

No goal-blocking gaps. All 6 ROADMAP success criteria are genuinely exercised by real assertions in the Phase 23 test block (tests/run.sh:2917-3280), not merely claimed. The full suite is green (PASS 429 / FAIL 0), shellcheck is clean at error severity, and the CR-01 fix was independently confirmed to have real regression value (the assertions fail against a reconstructed pre-fix approve.sh and pass against the shipped code). All 7 in-scope review findings are fixed in the committed code; the single accepted Info finding (IN-03 temp-file leak) is bounded and non-blocking.

The phase goal — the human-gated restructure skill installed and operational with pre-write safety gates blocking invalid proposals before approval — is achieved in the codebase. The only item that cannot be confirmed programmatically is the live interactive `/dev/tty` approve/skip/edit UX (criterion 2), whose deterministic non-TTY exit-2 half is automated and passing. Per the Phase 22 precedent, this single interactive sub-check is routed to human verification, so the phase status is **human_needed** (not gaps_found).

---

_Verified: 2026-05-29T02:45:07Z_
_Verifier: Claude (gsd-verifier)_
