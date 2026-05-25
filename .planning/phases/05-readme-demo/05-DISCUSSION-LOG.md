# Phase 5: README Demo - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 5-README Demo
**Areas discussed:** Demo script content, Reproducibility artifact, Conversion toolchain, README placement

---

## Demo Script Content

### Profile

| Option | Description | Selected |
|--------|-------------|----------|
| ts-next | Most popular stack; widest audience | ✓ |
| python-fastapi | Popular in data/ML circles | |
| generic (no --profile) | Bare scaffold; simpler but less impressive | |

**User's choice:** ts-next

---

### Command sequence

| Option | Description | Selected |
|--------|-------------|----------|
| init --dry-run + audit | Full trust story: plan without mutating, then verify | ✓ |
| init --dry-run only | Shorter; audit implied but not shown | |
| init --dry-run + audit + cost preview | Phase 6 not built yet; would be aspirational | |

**User's choice:** init --dry-run + audit

---

### Preflight step

| Option | Description | Selected |
|--------|-------------|----------|
| No — start directly at init | Cleaner; preflight is a detail | ✓ |
| Yes — show conjure preflight first | Full safe flow but adds ~10s | |

**User's choice:** No — start directly at init

---

### Target length

| Option | Description | Selected |
|--------|-------------|----------|
| Under 60 seconds | Tight enough that people watch fully | ✓ |
| 60–90 seconds | More breathing room; risks people skipping | |

**User's choice:** Under 60 seconds

---

## Reproducibility Artifact

### Committed script

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — committed scripts/record-demo.sh | Any contributor can re-record with one command | ✓ |
| No — document steps in README/CONTRIBUTING.md | Prose drifts from reality faster | |

**User's choice:** Yes — committed script

---

### Script scope

| Option | Description | Selected |
|--------|-------------|----------|
| mktemp dir + asciinema rec + agg convert | Self-contained one-script pipeline | ✓ |
| Only record — separate manual GIF conversion | Simpler but adds manual step | |

**User's choice:** Full pipeline in one script

---

### Automation method

| Option | Description | Selected |
|--------|-------------|----------|
| Automated with expect/autoexpect | Deterministic, reproducible every run | ✓ |
| Manual typing during asciinema rec | Natural feel but non-reproducible | |

**User's choice:** Automated with expect

---

## Conversion Toolchain

### Converter

| Option | Description | Selected |
|--------|-------------|----------|
| agg — GIF output | Official asciinema converter; renders everywhere | ✓ |
| asciinema SVG embed | Can look odd at some sizes | |
| termtosvg | Unmaintained (last commit 2020) | |

**User's choice:** agg — GIF output

---

### GIF location

| Option | Description | Selected |
|--------|-------------|----------|
| .github/assets/demo.gif | Consistent with existing logo.svg | ✓ |
| docs/assets/demo.gif | Works but inconsistent | |
| External hosting | Fragile external link | |

**User's choice:** .github/assets/demo.gif

---

### CI validation

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — CI check (file exists + non-empty) | Prevents broken demo in README | ✓ |
| No — trust contributor | Less CI noise; risk of missing/empty GIF | |

**User's choice:** Yes — CI check

---

## README Placement

### Position

| Option | Description | Selected |
|--------|-------------|----------|
| Replace the Quickstart code block | High-impact first impression | ✓ |
| New section before Quickstart | Dedicated section; slightly more scroll | |
| Inside Quickstart alongside code block | Belt-and-suspenders but cluttered | |

**User's choice:** Replace the Quickstart code block

---

### Caption

| Option | Description | Selected |
|--------|-------------|----------|
| Short italic caption below GIF | Context without clutter | ✓ |
| No caption | GIF speaks for itself; reader won't know what they're watching | |
| Full sentence above GIF | More instructional but adds prose bulk | |

**User's choice:** Short italic caption below GIF

---

## Claude's Discretion

- Exact `expect` delay timings between keystrokes
- Whether to add a re-record comment heading in `record-demo.sh`
- Exact `agg` width/height parameters (standard 120 cols)
- Whether `expect` is documented as contributor-only or added to CI deps

## Deferred Ideas

None — discussion stayed within phase scope.
