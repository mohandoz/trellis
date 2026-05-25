# Phase 08: Nyquist Compliance Backfill - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 08-nyquist-compliance-backfill
**Areas discussed:** File location, Command style, Document depth

---

## File Location

| Option | Description | Selected |
|--------|-------------|----------|
| Recreate phase dirs | Create .planning/phases/01-.../ etc. with just the VALIDATION.md; keeps provenance tied to original phase | ✓ |
| Flat docs/validation/ dir | Single docs/validation/01-VALIDATION.md through 07-VALIDATION.md | |
| Source-adjacent | VALIDATION.md next to the code it verifies (lib/, scripts/) | |

**User's choice:** Recreate phase dirs using exact original slugs from git history.
**Notes:** Naming scheme — match original slugs exactly (e.g., `01-pre-flight-cross-platform-hooks/`).

---

## Command Style

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone commands | Self-contained shell blocks with inline tmpdir setup; no run.sh dependency | ✓ |
| Wrap tests/run.sh | Call `bash tests/run.sh` and grep specific test IDs | |
| Both | Standalone primary + cross-reference to run.sh IDs | |

**User's choice:** Standalone commands only.

**Setup handling sub-question:**

| Option | Description | Selected |
|--------|-------------|----------|
| Inline setup per block | Each block: `TMPDIR=$(mktemp -d); trap 'rm -rf $TMPDIR' EXIT` | ✓ |
| Shared preamble section | One ## Setup section at top, reused by all blocks | |

**Notes:** Every code block must be independently copy-paste-runnable.

---

## Document Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — commands + expected output | ## Verify headers + shell block + ## Expected output; no background prose | ✓ |
| Structured — context + commands + expected + failure modes | Adds ## What this phase delivered + ## Common failure modes | |
| Ultra-minimal — commands only | Just shell blocks, no headers or expected output | |

**User's choice:** Minimal format.

**Req IDs sub-question:**

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — header with req IDs | `<!-- Covers: TECH-02a \| SAFE-01, SAFE-03 -->` | ✓ |
| No — no req ID refs | Traceability lives only in REQUIREMENTS.md | |

**Notes:** HTML comment header at top of each VALIDATION.md listing covered requirement IDs.

---

## Claude's Discretion

- Number and naming of `## Verify` sections per file — derived from phase success criteria and `tests/run.sh` test IDs
- Exact expected output snippets — use grep-friendly partial patterns, not verbatim full output

## Deferred Ideas

None.
