# Phase 08: Nyquist Compliance Backfill - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `VALIDATION.md` for phases 01, 02, 04, 05, 06, and 07 — each with executable
shell commands that verify the phase's shipped behavior without reading source code.
Does NOT add new functionality, change tests, or alter existing phase artifacts.

</domain>

<decisions>
## Implementation Decisions

### File Location
- **D-01:** Recreate the original v0.3.0 phase directories under `.planning/phases/` using
  their exact original slugs (e.g., `01-pre-flight-cross-platform-hooks/`,
  `02-dry-run-enforcement-chokepoint/`). Each directory gets one `{NN}-VALIDATION.md` file.
  The directory names match what was in git history before the v0.3.0 cleanup.

### Command Style
- **D-02:** Commands must be fully standalone — each verify block sets up its own tmpdir
  and tears it down inline:
  ```bash
  TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
  cd "$TMPDIR"
  # ... exercise the behavior ...
  ```
  No shared preamble section that contributors can accidentally skip.
  No references to `tests/run.sh` test IDs — VALIDATION.md must be self-contained and
  survive test suite refactors.

### Document Structure
- **D-03:** Minimal format only — no prose background section, no failure modes section.
  Structure per file:
  ```
  <!-- Covers: TECH-02x | <relevant test IDs from the phase> -->
  # Phase N VALIDATION

  ## Verify [behavior]
  ```bash
  ...commands...
  ```
  **Expected:** <what passing output looks like>
  ```
  Each `## Verify` section covers one testable claim from the phase's success criteria.

- **D-04:** Each VALIDATION.md starts with an HTML comment header listing the
  REQUIREMENTS.md requirement IDs it covers (e.g., `<!-- Covers: TECH-02a | SAFE-01, SAFE-03 -->`).
  This enables audit tooling to trace requirements → verify commands.

### Claude's Discretion
- Number and naming of `## Verify` sections within each file — derive from the phase's
  success criteria in ROADMAP.md and relevant test IDs in `tests/run.sh`.
- Exact expected output snippets — use partial-match patterns (grep-friendly) rather than
  exact byte strings where output may vary by platform or version.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase goals and success criteria
- `.planning/ROADMAP.md` §"Phase 08: Nyquist Compliance Backfill" — success criteria for
  this phase; also contains the success criteria for phases 01, 02, 04, 05, 06, 07 which
  inform what each VALIDATION.md must verify
- `.planning/REQUIREMENTS.md` §Tech Debt Clearance — TECH-02a through TECH-02f requirement
  definitions

### Test suite (understand existing test IDs before writing verify commands)
- `tests/run.sh` — full test suite; contains test IDs (SAFE-01/02, D-04/05, TEST-01 through
  TEST-07, COST-01 through COST-04, TELEM-01 etc.) that map to phase behaviors. Read to
  understand what each phase's behavior looks like from the outside.

### Phase slugs (recreate these directories)
Exact slugs from git history:
- `01-pre-flight-cross-platform-hooks`
- `02-dry-run-enforcement-chokepoint`
- `04-regression-suite-dry-run-proof`
- `05-readme-demo`
- `06-cost-estimator`
- `07-skill-firing-telemetry`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/run.sh` — source of truth for what behaviors are tested and what IDs they carry;
  standalone verify commands should exercise the same surface area as the matching tests
- `tests/lib/sandbox.sh` — sandboxing helpers; verify commands may inline similar setup
  rather than sourcing this file (keep VALIDATION.md standalone)
- `lib/mutate.sh` — dry-run chokepoint; Phase 02 VALIDATION.md verify commands will
  exercise this directly

### Established Patterns
- Test IDs follow `SAFE-NN`, `D-NN`, `TEST-NN`, `COST-NN`, `TELEM-NN` conventions already
  established in `tests/run.sh` — VALIDATION.md headers should reference these IDs

### Integration Points
- CI pipeline currently runs `bash tests/run.sh`; VALIDATION.md files are documentation
  only and do not need to be wired into CI (CI passes with them present per success criteria)

</code_context>

<specifics>
## Specific Ideas

- Inline tmpdir setup with trap (not shared preamble) is the chosen idiom — every code
  block must be independently copy-paste-runnable
- Expected output snippets should use grep-friendly partial patterns, not verbatim full output

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-Nyquist Compliance Backfill*
*Context gathered: 2026-05-25*
