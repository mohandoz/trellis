---
status: partial
phase: 22-conjure-adopt-cli-core-rollback
source: [22-VERIFICATION.md]
started: 2026-05-29T00:00:00Z
updated: 2026-05-29T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Interactive TTY recovery prompt (`[r]/[c]/[s]`)
expected: Run `conjure adopt` in a real terminal, `kill -9` it mid-run, then re-run interactively. `recovery_prompt()` reads from `/dev/tty` and presents `[r]ollback / [c]ontinue / [s]tart-fresh`. `r` restores from snapshot, `c` resumes reusing the existing snapshot, `s` discards state and snapshots anew; empty/unknown input re-prompts (no default).
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
