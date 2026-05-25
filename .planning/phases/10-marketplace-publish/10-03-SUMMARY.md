---
phase: 10-marketplace-publish
plan: "03"
subsystem: ci-marketplace-validation
tags: [ci, marketplace, plugin, version-consistency, claude-cli, schema-validation]
dependency_graph:
  requires: [valid-marketplace-json, valid-plugin-json]
  provides: [ci-version-drift-gate, ci-schema-validation-gate]
  affects: [ci.yml test job]
tech_stack:
  added: [claude-code apt package (CI only)]
  patterns: [signed-apt-repo-install, jq-empty-fallback, two-invocation-validate]
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Three new steps inserted in existing test job (not a new job) — per plan ordering constraint"
  - "claude CLI installed via signed apt repo (GPG verified) — not curl|bash per safety constraint"
  - "Two separate claude plugin validate invocations required — .validate . covers marketplace.json, explicit .claude-plugin/plugin.json covers plugin.json"
  - "No --strict flag — per RESEARCH.md Pitfall 2 (strict promotes warnings to errors)"
  - "jq // empty fallback used — avoids false pass when version field is absent (T-10-08 mitigated)"
metrics:
  duration: "49s"
  completed: "2026-05-25"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 10 Plan 03: CI Marketplace Validation Steps Summary

**One-liner:** Added three CI steps (version-consistency bash check, signed-apt claude CLI install, dual plugin validate) to the test job, catching version drift and schema errors on every PR.

## What Was Built

Three new steps were inserted into the existing `test` job in `.github/workflows/ci.yml`, after "Validate JSON" and before "Run kit test suite":

1. **Check version consistency** (Task 1) — Reads the VERSION file and compares it against `.plugins[0].version` in `marketplace.json` and `.version` in `plugin.json`. Uses `jq -r '... // empty'` fallback to avoid the "null" string false-pass when a field is absent. Fails CI with a descriptive message on any version drift. Delivers MKTPL-02.

2. **Install claude CLI** (Task 2) — Installs via the Anthropic signed apt repository (GPG key verified automatically by apt). Final line is `claude --version` as an install-gate (D-02: install failure = CI failure). No `continue-on-error`.

3. **Validate plugin manifests** (Task 2) — Two separate `claude plugin validate` invocations: `claude plugin validate .` (covers marketplace.json via repo-root discovery) and `claude plugin validate .claude-plugin/plugin.json` (explicit plugin.json). No `--strict` flag per RESEARCH.md Pitfall 2. Delivers MKTPL-03.

## Step Ordering (Final)

| # | Step | Status |
|---|------|--------|
| 1 | actions/checkout@v4 | existing |
| 2 | Install deps | existing |
| 3 | Lint shell scripts | existing |
| 4 | Validate JSON | existing |
| 5 | Check version consistency | **new (Task 1)** |
| 6 | Install claude CLI | **new (Task 2)** |
| 7 | Validate plugin manifests | **new (Task 2)** |
| 8 | Run kit test suite | existing |
| 9 | Assert demo GIF committed | existing |
| 10 | Audit script smoke | existing |

## Verification Results

| Check | Result |
|-------|--------|
| ci.yml is valid YAML | PASS |
| marketplace.json uses `.plugins[0].version // empty` | PASS |
| Install step uses signed apt repo | PASS |
| No `continue-on-error` on install step | PASS |
| `claude --version` present as install gate | PASS |
| Two separate `claude plugin validate` invocations | PASS |
| No `--strict` flag | PASS |
| All new steps in `test` job (not a new job) | PASS |

## Commits

| Task | Description | Hash |
|------|-------------|------|
| Task 1 | Add version-consistency check step to ci.yml test job | de263ee |
| Task 2 | Add claude CLI install and plugin validate steps to ci.yml | d9670eb |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All steps are complete implementations with no placeholder logic.

## Threat Flags

No new threat surface beyond what is in the plan's threat model. The signed apt repo install (T-10-07) and `// empty` jq fallback (T-10-08) are both mitigated as specified.

## Self-Check: PASSED

- [x] `.github/workflows/ci.yml` exists and is valid YAML
- [x] "Check version consistency" step present, uses `.plugins[0].version // empty`
- [x] "Install claude CLI" step present, uses signed apt repo, no `continue-on-error`
- [x] `claude --version` is the final line of the install step
- [x] "Validate plugin manifests" step has two invocations, no `--strict`
- [x] All three steps are in the `test` job, after "Validate JSON", before "Run kit test suite"
- [x] Commit de263ee exists (Task 1)
- [x] Commit d9670eb exists (Task 2)
