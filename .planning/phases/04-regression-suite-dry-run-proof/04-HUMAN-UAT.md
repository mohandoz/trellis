---
status: partial
phase: 04-regression-suite-dry-run-proof
source: [04-VERIFICATION.md]
started: 2026-05-25T00:00:00Z
updated: 2026-05-25T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Windows CI job runtime validation
expected: Push to GitHub → `windows-hook-wiring` job completes green on `windows-latest`. Scaffold fixture step runs `cli/conjure init`, Assert node hook wiring finds `node` in settings.json, Assert no bash hook regression step confirms no `bash .claude/hooks` in settings.json.
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
