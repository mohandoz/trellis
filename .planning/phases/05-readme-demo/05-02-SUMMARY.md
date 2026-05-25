---
phase: 05-readme-demo
plan: "02"
subsystem: docs
tags: [readme, gif, ci, demo, asciinema]
status: complete
completed: 2026-05-25

key-files:
  created:
    - .github/assets/demo.gif
  modified:
    - README.md
    - .github/workflows/ci.yml

requirements-satisfied:
  - DOCS-01
---

## Summary

Plan 02 delivered the three-part README demo: generated `.github/assets/demo.gif` (314 KB, GIF89a, ~35 frames) by running `scripts/record-demo.sh` on the contributor machine with asciinema 3.2.0 + agg 1.8.1 + expect 5.45; replaced the Quickstart bash code block in README.md with a centered `<img>` embed (width=700) and the locked D-10 caption; added an "Assert demo GIF committed" step (`test -s .github/assets/demo.gif`) to the CI `test` job between "Run kit test suite" and "Audit script smoke".

## What Was Built

- **`.github/assets/demo.gif`** — 314 KB animated GIF showing `conjure init --dry-run --profile=ts-next .` (45 lines of dry-run output) followed by `conjure audit` (PASS: 4 / WARN: 8 / FAIL: 0), plays in under 60 seconds
- **`README.md` Quickstart** — GIF embed replaces the three-step install/init/open code block; `<div align="center">` wrapper with `width="700"` and locked italic caption per D-09/D-10
- **`.github/workflows/ci.yml`** — one new step in the existing `test` job; no new job added; job count stays at 3

## Deviations

None. All acceptance criteria satisfied; 176/176 tests pass after commit.

## Self-Check

- [x] `.github/assets/demo.gif` committed and non-empty (314 KB, GIF89a magic bytes confirmed)
- [x] `grep -q '.github/assets/demo.gif' README.md` passes
- [x] `grep -q 'zero mutations, fully auditable' README.md` passes (locked D-10 caption)
- [x] `grep -q 'div align="center"' README.md` passes
- [x] Old three-step bash code block removed from README
- [x] `grep -q 'test -s .github/assets/demo.gif' .github/workflows/ci.yml` passes
- [x] CI job count still 3 (`runs-on:` lines = 3)
- [x] `bash tests/run.sh` → PASS: 176 FAIL: 0

Self-Check: PASSED
