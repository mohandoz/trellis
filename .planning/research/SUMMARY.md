# Project Research Summary

**Project:** Conjure — v0.3.0 "Testing + telemetry" milestone
**Domain:** Open-source developer tooling — Claude Code init kit (POSIX bash CLI + Node `.mjs` hooks)
**Researched:** 2026-05-24
**Confidence:** HIGH

## Executive Summary

This is a *subsequent* milestone on a mature OSS init kit (v0.2.1, 112 green self-tests, 9 profiles, 4 compliance overlays). v0.3.0 is the "earn-trust-before-reach" milestone: five capabilities — per-profile test fixtures, a regression suite, genuinely-enforced `--dry-run`, local-only skill-firing telemetry, and an `audit --cost` estimator — plus the pre-flight hardening that ties them together. Research across all four files converges on one theme: **this milestone is fundamentally about closing the gap between what Conjure *claims* and what it *verifiably does*.** Two of the five features (`--dry-run`, cross-platform hooks) are already advertised but provably broken in the working tree today; the suite is what proves the rest.

The recommended approach is **deliberately dependency-free and local-first**, matching the kit's existing constraints. Extend the hand-rolled `tests/run.sh` with a per-fixture golden-file loop (bats-core v1.13.0 only if unit-level specs grow; shellspec is disqualified as unmaintained since 2021). Telemetry is an append-only JSONL file written by a Claude Code hook *inside the target project* — never the kit — parsed later by `jq`. The cost estimator is a `chars/4` heuristic times a baked, dated price table, explicitly labeled an estimate with a ±band; no tokenizer is bundled (Anthropic's own tokenizer is inaccurate for Claude 4.x), with an optional opt-in online `--exact` path. Architecturally, all writes funnel through a new `lib/mutate.sh` chokepoint so `--dry-run` is enforced in *one* place instead of N call sites, and pre-flight is extracted to `scripts/preflight.sh` so both the CLI and tests can reuse it.

The dominant risk is **trust collapse from getting telemetry wrong** — the April-2026 GitHub CLI opt-out backlash is the cautionary tale, and Conjure is a safety/compliance tool where phoning home would be self-contradicting. Telemetry must be off-by-default, opt-in, local-only (zero network egress), PII-free, and user-inspectable, with a build-time no-egress test that greps every hook for `curl`/`fetch`/`http`/socket and fails CI if found — turning the trust promise into an enforced invariant. The secondary risks are the two live bugs (dry-run mutates disk; Windows hooks are wired `bash`-only and silently dead) and a cost estimator that quotes a precise-looking number users will screenshot and be burned by. All are well-understood with concrete prevention strategies below.

## Key Findings

### Recommended Stack

The kit's hard constraint — POSIX bash + Node `.mjs`, no heavy runtime dependency — drives every pick. Testing extends the existing hand-rolled `tests/run.sh` rather than adopting a framework, because per-profile fixtures are a `for` loop over `audit-setup.sh`, not a framework need. Telemetry, cost, and pre-flight all reuse tools already in pre-flight (`jq`, `node` stdlib). The only new vendored option is bats-core, and only as an optional git submodule for unit-level specs. See `.planning/research/STACK.md`.

**Core technologies:**
- **Hand-rolled `tests/run.sh` (extended):** fixture-driven regression loop — already ships, zero install, models the assertion pattern perfectly.
- **bats-core v1.13.0 (optional submodule):** unit-level specs (dry-run invariants, arg parsing) only if inline helpers get unwieldy — actively maintained (Nov 2025), bash 3.2+, TAP output. shellspec rejected (unmaintained since Jan 2021).
- **Append-only JSONL + `jq`:** local telemetry store written by a hook, folded for the retire-list — no SDK, no sqlite, no phone-home.
- **`chars/4` heuristic + baked price table:** cost estimate — no tokenizer dependency (Anthropic's is inaccurate for Claude 4.x); optional opt-in `--exact` via lazy `npx @anthropic-ai/sdk` `countTokens()` when creds exist.
- **`command -v` probe (bash) + mirrored `.mjs` probe:** OS-aware pre-flight with copy-pasteable install hints (brew/apt/winget/npm); never auto-installs.

### Expected Features

The audience (developers scrutinizing a dev tool) makes "verifiable" the table-stakes bar. See `.planning/research/FEATURES.md`.

**Must have (table stakes):**
- Telemetry OFF by default, opt-in, **local-only / zero network egress**, PII-free, with a documented schema (`TELEMETRY.md`) and inspectable log (`conjure telemetry show`). Honor `DO_NOT_TRACK`.
- Per-profile test fixtures audited green + a one-command, CI-gated regression suite (golden-file pattern, PR-approved updates).
- `--dry-run` that genuinely mutates nothing, *everywhere*, with a test asserting zero mutation.
- Pre-flight dependency verification with one-command, OS-correct fix-its (never auto-install).

**Should have (competitive differentiators):**
- Local-only skill-firing telemetry → quarterly "retire-list" signal — turns the dreaded word "telemetry" into a trust asset, on-thesis with "less context = better adherence."
- `conjure audit --cost` heuristic estimator with a stated ±band — no comparable kit estimates harness token cost.
- Failure-mode reproductions encoded as tests — turns FAILURE-MODES.md docs into guarantees.
- asciinema → GIF demo in README — highest-ROI adoption move, safe to record once dry-run is real.

**Defer (v0.3.x / v0.4.0+):**
- Dynamic CI-generated test-count badge; `--print-install` aggregate block; per-profile cost rows in SIZING.md.
- Distribution (Marketplace, Homebrew, Docker), any aggregate/network telemetry, web dashboard — explicitly out of scope per PROJECT.md.

### Architecture Approach

v0.3.0 work slots into the existing `cli/conjure → scripts/*.sh` layout by adding one new top-level `lib/` (sourced helpers) and promoting throwaway fixtures into committed per-profile fixtures. Two patterns are load-bearing: a **single mutation chokepoint** (`lib/mutate.sh`) so `--dry-run` is parsed once and enforced at the write site, and **golden-file fixtures** (`EXPECT.txt` per profile) so the runner stays a generic diff loop. The kit stays stateless: only the *shipped hook running inside a target project* writes telemetry; the kit only reads it during `audit --cost`. See `.planning/research/ARCHITECTURE.md`.

**Major components:**
1. **`scripts/preflight.sh`** (extracted from inline `cmd_preflight()`) — dependency checks + fix-its, reusable by CLI and tests.
2. **`lib/mutate.sh`** — single chokepoint for every filesystem write; honors `DRY_RUN`; logs intended mutations.
3. **`lib/cost.sh`** — pure `chars→tokens→$` functions + per-skill breakdown, sourced by `audit-setup.sh`.
4. **`tests/fixtures/<profile>/` + `EXPECT.txt`** — committed example projects + declarative golden assertions; `tests/run.sh` diffs normalized audit output.
5. **`templates/hooks/skill-telemetry.{sh,mjs}`** — runtime hook appending JSONL to the *target* project's `.claude/telemetry/`.

### Critical Pitfalls

1. **`--dry-run` is a lie today (LIVE BUG).** `conjure init --dry-run` parses the flag but never threads `DRY_RUN` into `init-project.sh`, profile `apply.sh`, or the unconditional `.conjure-version` stamp — only migrations honor it. Dry-run mutates disk now. **Avoid:** route all writes through `lib/mutate.sh`; thread `DRY_RUN` into every child incl. the version stamp; prove it with a tree+mtime snapshot test.
2. **Cross-platform hooks wired `bash`-only (LIVE BUG).** `templates/settings.json.tmpl` hardwires `bash .claude/hooks/*.sh` for all four hooks; on native Windows without Git Bash every hook silently no-ops, despite the `.mjs` files existing. **Avoid:** emit `node .claude/hooks/<name>.mjs` (universal) or branch by detected OS at init; add a test asserting the wired command references a runtime present on the OS; add a `windows-latest` CI leg.
3. **Telemetry that erodes trust — the star-killer.** Opt-out, silent, or phone-home telemetry triggers the exact backlash Conjure is chasing stars to avoid. **Avoid:** local-only by design, opt-in, PII-free; build-time no-egress grep test on all hooks; log is gitignored + names-only; document loudly.
4. **Cost estimator uses the wrong tokenizer / over-precise framing.** `tiktoken`/heuristics differ 20–40% from Claude's tokenizer; a precise-looking number gets quoted and burns users. **Avoid:** label an order-of-magnitude estimate, print model + `$/Mtok` + as-of date + ±band; price in a dated constant block; offline default, opt-in online `--exact` for accuracy.
5. **Fixtures leak real `$HOME`/global config/network, flake, or rot silently.** Un-sandboxed fixtures read the dev's real `~/.claude`/git/tools; time/path/randomness cause heisentests; green-only suites mask regressions. **Avoid:** sandbox `HOME`/`XDG_CONFIG_HOME`/`CLAUDE_CONFIG_DIR`/`PATH` in `setup()`; copy fixtures to tmp; PATH-shim external tools; normalize output before diffing; ship ≥1 intentionally-failing fixture and assert *specific* findings, not just exit 0.

## Implications for Roadmap

Research yields a clear **dependency-ordered build sequence** (from ARCHITECTURE.md, corroborated by the pitfall-to-phase mapping). Safety primitives first → trustworthy fixtures → the regression net that guards everything → analytical features (cost, telemetry) last, since they consume the fixtures and the extended audit.

### Phase 1: Pre-flight extraction + cross-platform hook wiring
**Rationale:** Smallest, standalone, no deps; the fix-it strings are reused later. Pairs naturally with fixing the `bash`-only hook wiring (LIVE BUG #2), since both are about "detect the platform, emit the right thing."
**Delivers:** `scripts/preflight.sh` (extracted from inline `cmd_preflight()`), OS-aware install hints, and per-platform hook wiring (`node .mjs` universal or OS-branched) in `settings.json.tmpl`.
**Addresses:** Pre-flight dependency verification with one-command fix-its (table stakes).
**Avoids:** Pitfall 5 (bash-only hooks silently dead on Windows), Pitfall UX (wrong installer per OS).

### Phase 2: `lib/mutate.sh` + dry-run enforcement
**Rationale:** Must precede fixtures — you want `--dry-run` correct before you trust generated fixtures. Independent of telemetry/cost. Closes LIVE BUG #1.
**Delivers:** `lib/mutate.sh` chokepoint; `init-project.sh`, profile/compliance `apply.sh`, and the `.conjure-version` stamp all routed through it; `DRY_RUN` threaded everywhere.
**Uses:** Sourced-library bash pattern (STACK.md / ARCHITECTURE.md Pattern 1).
**Avoids:** Pitfall 1 (dry-run partial mutation) — the worst credibility bug in the tree.

### Phase 3: Per-profile test fixtures (sandboxed)
**Rationale:** Depends on a trustworthy `init` (Phases 1–2). Generate each via `conjure init --profile=X`, fill, audit green, snapshot to `EXPECT.txt`.
**Delivers:** `tests/fixtures/<profile>/` (9 profiles) + `EXPECT.txt`; shared sandboxed `setup()` isolating `HOME`/`XDG_CONFIG_HOME`/`CLAUDE_CONFIG_DIR`/`PATH`; PATH-shimmed external tools; ≥1 intentionally-failing fixture.
**Implements:** Golden-file fixture pattern (ARCHITECTURE.md Pattern 3).
**Avoids:** Pitfalls 2, 6, 7 (env leakage, flakiness, silent rot).

### Phase 4: Regression suite wiring + dry-run proof
**Rationale:** Depends on fixtures (Phase 3) existing. Adds the golden-diff loop and the test that *proves* Phase 2's dry-run by asserting the fixture tree is byte-identical after `--dry-run`.
**Delivers:** `tests/run.sh` fixture loop; normalized-output golden diffing; the dry-run snapshot assertion; `update-fixtures` regenerate-and-diff helper; `windows-latest` CI leg.
**Addresses:** One-command CI-gated regression suite (table stakes); clone-and-verify trust signal.
**Avoids:** Pitfall 7 (regenerate-and-diff prevents silent rot); verifies Pitfalls 1 and 5.

### Phase 5: `lib/cost.sh` + `audit --cost`
**Rationale:** Depends only on audit's existing char count; can overlap Phases 3–4, but fixtures give it test targets. Lower trust-risk than telemetry, so it lands before it.
**Delivers:** `lib/cost.sh` (`chars/4` + dated baked price table + per-skill breakdown); `audit --cost` block printing model + `$/Mtok` + as-of date + ±band; optional opt-in `--exact` online path.
**Uses:** Existing `.claude/` char count, SIZING.md baselines (STACK.md / FEATURES.md accuracy bar).
**Avoids:** Pitfall 4 (wrong tokenizer / over-precise framing).

### Phase 6: Skill-firing telemetry (last)
**Rationale:** Last because (a) it needs Claude Code hook-event verification at phase time, and (b) the retire-list it feeds plugs into the now-extended `audit --cost` (Phase 5) and is best validated against fixtures (Phase 3) carrying sample logs.
**Delivers:** `templates/hooks/skill-telemetry.{sh,mjs}`; settings registration; append-only `.claude/telemetry/skill-events.jsonl` in the *target*; `TELEMETRY.md` schema; `conjure telemetry show`; retire-list block in audit; **build-time no-egress test** on all hooks.
**Addresses:** The headline differentiator, done the trust-preserving way.
**Avoids:** Pitfall 3 (the star-killer) — local-only/no-egress is a phase success criterion, not an afterthought.

### Phase Ordering Rationale

- **Dependency-driven, straight from architecture research:** preflight → dry-run chokepoint → fixtures → regression suite (asserts dry-run) → cost → telemetry. Each phase unblocks the next; the regression net exists before the analytical features it must guard.
- **Live bugs front-loaded:** the two already-shipping bugs (dry-run, Windows wiring) are fixed in Phases 1–2 because everything downstream (fixtures, demo GIF) depends on a trustworthy `init`.
- **Trust-risk ordered last:** telemetry — the highest reputational risk — lands last, with the most verification (no-egress test, schema doc, inspector) and after the regression suite can guard it.
- **The demo GIF** (a docs item) is best slotted after Phase 4, once dry-run is provably enforced and fixtures are green — record without fear of mutation.

### Research Flags

Phases likely needing deeper research during planning (`/gsd:plan-phase --research-phase`):
- **Phase 6 (telemetry):** **MUST verify the exact Claude Code skill-load hook event name/shape against installed CC ≥2.1.117** before building. Stack research expects `PreToolUse` with `tool_name: "Skill"` + `tool_input.skill_name` plus `InstructionsLoaded`, but architecture research flags this as LOW-confidence-until-confirmed. Telemetry fidelity depends on it; have a `SessionStart`/`Stop` coarse-signal fallback ready.
- **Phase 5 (cost), light:** confirm the May-2026 price table and the chars-per-token ratio's real-world band against a representative harness; the `--exact` SDK call shape needs a quick check.

Phases with standard patterns (skip research-phase):
- **Phase 1 (pre-flight):** `command -v` probing + OS detection are well-trodden; half already exists.
- **Phase 2 (dry-run chokepoint):** standard sourced-lib bash refactor; pattern fully specified in ARCHITECTURE.md.
- **Phase 3–4 (fixtures + suite):** golden-file/sandboxing patterns are well-documented and partly modeled by the existing single-fixture CI job.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Hooks API, pricing, tokenizer status, bats/shellspec maintenance all verified against official/primary sources. |
| Features | HIGH | Telemetry/dry-run/golden patterns verified across current sources incl. the April-2026 gh telemetry backlash. Cost-accuracy band is MEDIUM (Claude's exact tokenizer is not public). |
| Architecture | HIGH | Derived from reading the actual codebase this session; integration points verified against real files. One LOW spot: exact hook event name (flagged for Phase 6). |
| Pitfalls | HIGH | Most pitfalls verified against this repo's own source with `file:line`; two are confirmed live bugs in the tree. |

**Overall confidence:** HIGH

### Gaps to Address

- **Claude Code skill-load hook event name/shape (Phase 6):** the single real unknown. Verify against installed CC ≥2.1.117 at phase-planning time; design the telemetry hook with a coarse `SessionStart`/`Stop` fallback so the retire-list still works if the granular `Skill` event differs from expectation.
- **Cost-estimate accuracy band (Phase 5):** the `chars/4` heuristic is well-sourced for English (~5–15%) but Claude's BPE differs and isn't public. Handle by *framing* (label estimate, print assumptions/date/±band) rather than chasing precision; offer opt-in `--exact` for users who need it.
- **Compliance-overlay fixture combinatorics (Phase 3):** 9 profiles × 4 overlays is too many to fixture exhaustively. Pick representative pairs, not the full matrix, to keep CI fast and hermetic.

## Sources

### Primary (HIGH confidence)
- This repository, read directly this session — `cli/conjure`, `scripts/init-project.sh`, `scripts/audit-setup.sh`, `tests/run.sh`, `templates/settings.json.tmpl`, `templates/hooks*/`, `profiles/*/apply.sh`, `.github/workflows/ci.yml`, FAILURE-MODES.md, PROJECT.md, planning/ROADMAP.md (the two live bugs are confirmed with `file:line`).
- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks) — event list, `PreToolUse`/`tool_name:"Skill"`, `InstructionsLoaded`, exit-code/output semantics.
- [bats-core releases](https://github.com/bats-core/bats-core) (v1.13.0, 2025-11) and [shellspec releases](https://github.com/shellspec/shellspec) (0.28.1, 2021 — unmaintained).
- [@anthropic-ai/tokenizer (npm)](https://www.npmjs.com/package/@anthropic-ai/tokenizer) — inaccurate for Claude 3+; [Claude token counting](https://platform.claude.com/docs/en/build-with-claude/token-counting) and [pricing](https://platform.claude.com/docs/en/about-claude/pricing).
- [GitHub CLI opt-out telemetry changelog](https://github.blog/changelog/2026-04-22-github-cli-opt-out-usage-telemetry/) — primary cautionary tale.

### Secondary (MEDIUM confidence)
- CLI telemetry best practices (marcon.me), gh backlash coverage (Groundy, The Register), Next.js telemetry issues (vercel/next.js #59686).
- Golden/snapshot testing and `terraform plan` dry-run model references.
- Token-cost estimation guides (ML Journey, tokenx, Winder.ai) — corroborate 20–40% cross-tokenizer drift.
- OSS adoptability / README / asciinema references.

### Tertiary (LOW confidence)
- Exact Claude Code skill-load hook event name — inferred from current docs, **not verified against an installed CC ≥2.1.117 instance**; flagged for Phase 6 verification.

---
*Research completed: 2026-05-24*
*Ready for roadmap: yes*
