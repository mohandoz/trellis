# Phase 23: Restructure Skill + Safety Gates - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the human-gated `restructure` skill that conjure adopt installs into a
target repo, plus the pre-write safety gates that block invalid LLM proposals
**before** the user is ever asked to approve them. The skill turns an oversized
CLAUDE.md + doc sprawl into a ≤100-line core + extracted skills/subagents +
linked references + archived files — proposing a numbered, per-step-approved
plan and applying changes ONLY through the Phase 22 `conjure adopt` seam
(`--update-manifest` to propose, `--apply-step` to apply). The skill itself is
restricted to `[Read, Bash]` and never calls Write/Edit on project files.

**Requirements:** RESTR-01, RESTR-02, RESTR-03, RESTR-04, RESTR-05, RESTR-06.

**Not this phase:** the `conjure adopt` CLI / op-executor / rollback (Phase 22 —
already shipped + tested); integration tests + Argus fixture (Phase 24). Phase 23
builds the skill + its gate helpers that RIDE the Phase 22 seam; it does not
modify the adopt pipeline itself except where a gate helper is shared.

</domain>

<decisions>
## Implementation Decisions

### Skill structure & the ≤200-line constraint (resolves the open question)
- **D-01:** Thin `SKILL.md` = orchestration prose ONLY; heavy logic lives in bash
  helper scripts shipped alongside the skill (e.g. `gates/*.sh` in the skill dir).
  This resolves the "≤200 lines covering load/invariant/propose/approve/patch/audit"
  open question without a planning spike — SKILL.md narrates the flow and calls
  helpers via Bash. (Cramming all logic into SKILL.md was rejected — risks the
  ≤200-line cap.)
- **D-02:** Safety-gate validators are bash helper scripts the skill invokes via
  Bash (constraint-extract, invariant-verify, decision-vocabulary scan); RESTR-05's
  pre-write audit reuses the existing `conjure audit`. (New adopt.sh subcommands
  rejected — keep the gates in the skill's own dir, not the CLI core.)
- **D-03:** `INVARIANTS.txt` is written to `.conjure-adopt-state/INVARIANTS.txt`
  (transient, beside `staging/`), not the target root (avoids repo clutter).
- **D-04:** The skill mutates files ONLY via `conjure adopt --update-manifest`
  (write proposed ops + staged content) then `conjure adopt --apply-step <id>`
  (apply) — the Phase 22 seam. Skill stays `[Read, Bash]` (RESTR-02). Direct
  staging writes rejected — every mutation must route through the adopt chokepoint.

### Constraint extraction & invariant gate (RESTR-04)
- **D-05:** The skill (LLM, reading via Read) proposes the invariant list →
  written to `INVARIANTS.txt`; a deterministic bash gate then verifies the
  PROPOSED condensed CLAUDE.md contains every invariant. (Pure keyword heuristic
  rejected — misses nuance; but the *verification* is deterministic so the gate is
  reproducible.)
- **D-06:** Invariant scope = imperative/prohibition lines (`must`/`never`/`always`/
  `do not`), exit-code rules (e.g. `exit 2`), size caps, and named commands /
  backtick'd tokens. (Only-explicit-"MUST" rejected — too narrow.)
- **D-07:** Gate match strictness = normalized substring (case-insensitive,
  whitespace-collapsed) so legitimate reflow/condensing doesn't false-block.
  (Exact byte match rejected — brittle against condensing.)
- **D-08:** Gate failure = BLOCK before approval; print the list of missing
  invariants; the user never sees the proposal until it passes (criterion 4).
  (Warn-but-allow rejected.)

### Approval UX (RESTR-03, RESTR-06)
- **D-09:** 50+ file corpora use per-class grouped approval — ONE prompt per
  classification bucket (the Phase 21 6-bucket taxonomy), never one prompt per
  file; RESTRUCTURE-LOG.md records only a summary line for bulk operations
  (criterion 3, RESTR-03).
- **D-10:** Per-step verbs = `approve / skip / edit`. `approve` applies the step,
  `skip` leaves the file as-is, `edit` re-opens the staged file for the user to
  adjust, then RE-RUNS the gates before re-prompting (criterion 2). Skill never
  proceeds without an explicit response.
- **D-11:** Decision-vocabulary scan: files matching `decided` / `we chose` /
  `rationale` / `do not` / `never` are pulled OUT of bulk archive into INDIVIDUAL
  confirmation (RESTR-06). (Flag-but-keep-in-bulk rejected.)
- **D-12:** No-TTY behavior = `exit 2`, never auto-approve (mirror adopt D-13 /
  resolve.sh /dev/tty pattern). Read the approval from `/dev/tty`.

### Gate sequencing & adopt-seam integration (RESTR-02, RESTR-05)
- **D-13:** Pre-write audit (RESTR-05): run `conjure audit` on the PROPOSED staging
  file BEFORE the approval prompt; block on `@import` lines or cap breaches and
  show the audit output; no approval prompt for invalid content (criterion 5).
- **D-14:** Gate order = invariant-check (D-05/D-08) + audit-gate (D-13) BOTH run
  before approval ("before the user sees the proposal", criteria 4 & 5).
- **D-15:** Archive steps are sequenced LAST in the proposed plan (criterion 6);
  combined with D-11's decision-vocabulary individual confirmation.
- **D-16:** Install path: adopt scaffolds `templates/skills/restructure/` into the
  target's `.claude/skills/restructure/` (criterion 1). Frontmatter declares
  `allowed-tools: [Read, Bash]`; `SKILL.md` is ≤200 lines. (A separate
  `conjure restructure` CLI command rejected — it's a skill, per RESTR-01.)

### Claude's Discretion
- Exact helper-script names/layout under the skill dir; the precise INVARIANTS.txt
  line format; the normalized-substring matcher implementation; the per-bucket
  approval prompt wording; how `edit` surfaces the staged file (e.g. print path +
  re-read). All at Claude's discretion during planning, consistent with adopt's
  existing `/dev/tty` + summary-log conventions.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The Phase 22 adopt seam** — `conjure adopt --update-manifest` (writes proposed
  ops + staged content into `adopt-manifest.json` `restructure_steps[]`) and
  `--apply-step <id>` (validates op-allowlist {write,archive,extract} + path
  containment, applies via `lib/mutate.sh`, marks `status: applied`,
  `log_step RESTRUCTURE`). Staging contract: content lives at
  `.conjure-adopt-state/staging/<file>`; manifest op references it as
  `{ op, dest, src, status }` (D-07 of Phase 22). The skill is the PROPOSER half.
- **`conjure audit`** (`scripts/audit-setup.sh`, sources `lib/caps.sh`) — reused
  for RESTR-05 pre-write gate (@import + cap-breach detection). Exit contract
  0=pass / 1=warn / 2=err.
- **Phase 21 6-bucket classification taxonomy** + `inventory_scan` /
  `adopt-manifest.json` (already records per-file classification) — drives D-09's
  per-class grouped approvals.
- **`lib/log.sh`** `log_step` — summary-line logging for bulk ops (D-09, SAFE-07).
- **`scripts/resolve.sh`** (~lines 39-77) — the `/dev/tty` read + `exit 2` on
  non-TTY model to mirror for the approval prompt (D-10, D-12).
- **`scripts/init-project.sh`** lines 58-70 — the skill-scaffold loop
  (`mutate_cp "$KIT/templates/skills/<name>" ".claude/skills/<name>"`). Adopt must
  scaffold `restructure` the same way (D-16).
- **`templates/skills/<name>/SKILL.md`** — existing skill template format to mirror
  (frontmatter `name` + `description`; here add `allowed-tools: [Read, Bash]`).

### Established Patterns
- All target mutations route through `lib/mutate.sh`; the skill never writes
  directly — it proposes, adopt applies (RESTR-02 chokepoint).
- POSIX bash 3.2+; hooks/CLI `exit 2` never `exit 1`; size caps enforced
  (SKILL.md ≤200 lines — this skill must comply, criterion 1).
- `/dev/tty` read + non-TTY `exit 2` for any interactive prompt.

### Integration Points
- `adopt-manifest.json` `restructure_steps[]` — the skill writes proposals here via
  `--update-manifest`; adopt applies via `--apply-step`.
- `.conjure-adopt-state/staging/` — proposed content files; `INVARIANTS.txt` sits
  beside it (D-03).
- `scripts/init-project.sh` (or adopt's scaffold step) — add `restructure` to the
  scaffolded skills so it lands in the target after `conjure adopt` (D-16,
  criterion 1).

</code_context>

<specifics>
## Specific Ideas

- Skill dir layout (illustrative): `templates/skills/restructure/SKILL.md`
  (orchestration prose, ≤200 lines) + `templates/skills/restructure/gates/`
  (`extract-invariants` helper, `verify-invariants` deterministic gate,
  `decision-scan` helper) invoked via Bash.
- Approval flow (illustrative): load manifest + classifications → extract invariants
  → for each proposed step: run invariant-verify + `conjure audit` gates → if pass,
  present per-class grouped `approve/skip/edit` from `/dev/tty` → on approve,
  `conjure adopt --apply-step <id>`. Archive steps last; decision-vocabulary files
  individually confirmed.

</specifics>

<deferred>
## Deferred Ideas

- Integration tests + Argus brownfield fixture exercising the full
  adopt+restructure pipeline — **Phase 24**.
- Any TUI/rich-rendering of the approval plan — out of scope; plain-text +
  `/dev/tty` mirrors the established resolve.sh pattern.

None expanded Phase 23 scope — discussion stayed within the phase boundary.

</deferred>

---

*Phase: 23-restructure-skill-safety-gates*
*Context gathered: 2026-05-29 via smart discuss (autonomous)*
