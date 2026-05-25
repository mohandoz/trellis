# Stack Research

**Domain:** v0.3.0 "Testing + telemetry" tooling for the Conjure Claude Code harness kit (POSIX bash CLI + Node.js `.mjs` hooks)
**Researched:** 2026-05-24
**Confidence:** HIGH (hooks API, pricing, tokenizer status verified against official sources; shell-framework tradeoff is well-established)

## TL;DR Picks (one line each)

| Decision | Pick | Confidence |
|----------|------|------------|
| (a) Fixture regression testing | **Extend hand-rolled `tests/run.sh`**, optionally **vendor `bats-core` v1.13.0 as a git submodule** for new unit-level specs. Do NOT add shellspec or npm test deps. | HIGH |
| (b) Skill-firing telemetry | **Append-only JSONL log written by a `PreToolUse` (tool_name=`Skill`) hook**, also capture `InstructionsLoaded`. Pure bash + `.mjs`, no external service. | HIGH |
| (c) Cost estimator | **chars/4 heuristic** over harness file bytes × a small per-model price table baked into `conjure`. Do NOT bundle a tokenizer or call the API by default. | HIGH |
| (d) Cross-platform preflight | **`command -v` table in bash + a mirrored `.mjs` probe**, OS-detected install hints (brew/apt/winget/npm). Already partially exists in `cmd_preflight`. | HIGH |

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Hand-rolled `tests/run.sh`** | (current, extend) | Fixture-driven regression suite, audit assertions per profile | Already ships, 112 tests green, zero install. The fixture suite is fundamentally "run `audit-setup.sh` against `tests/fixtures/<profile>/` and assert exit code + grep output" — this is a loop, not a framework need. Keeps the kit dependency-free, which is a core constraint. |
| **bats-core** | **v1.13.0** (2025-11-07) | OPTIONAL: structured unit-level specs for individual CLI functions / dry-run assertions | TAP-compliant, pure bash, runs on bash 3.2+, installable as a **git submodule with zero runtime deps**. Only adopt if hand-rolled assertions get unwieldy; introduce alongside, not as a replacement. |
| **bats-support + bats-assert** | **v2.2.4** | OPTIONAL: `assert_output`, `assert_success`, `assert_equal` helpers for bats | The ergonomic layer that makes bats worth it. Not on npm — must be submodules. Only pull in if bats is adopted. |
| **shellcheck** | **v0.11.0** (2025-08) | Lint all `.sh` (already in CI) | Keep pinned. v0.11 adds SC2327–2335; relevant to the new fixture/telemetry scripts. CI already runs it (relaxed to error-only per recent commit). |
| **Node.js (built-in only)** | **≥18 LTS** | `.mjs` hooks for Windows + cost-estimator math + dry-run helpers | Already a declared platform. Use `node:fs`, `node:process`, `node:os`, `node:child_process` from stdlib only. No npm `dependencies` block. |
| **jq** | system (preflight-checked) | JSONL telemetry parsing in `conjure audit`, fixture JSON validation | Already a preflight dependency and used in `tests/run.sh`. Reuse for reading the telemetry log; don't add a JSON lib. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **`@anthropic-ai/sdk`** | latest (~0.6x line) | `client.messages.countTokens()` for an *opt-in* `--cost --exact` mode only | ONLY behind an explicit flag, lazy `npx`-invoked, never a hard dep. Free API, rate-limited. Default path must stay offline. Most users won't have credentials configured; design must degrade to the heuristic silently. |
| **(none for tokenizing)** | — | — | Deliberately empty. See "What NOT to Use." The chars/4 heuristic needs no library. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `git submodule` | Vendor bats-core if adopted | `git submodule add https://github.com/bats-core/bats-core tests/bats`. Pin to v1.13.0 tag. CI must `git submodule update --init`. |
| GitHub Actions (existing `ci.yml`) | Run fixture suite on push | Add a matrix entry per OS (`ubuntu-latest`, `macos-latest`, and `windows-latest` for the `.mjs` hook path) to actually exercise cross-platform claims. |
| `tput`/ANSI (existing pattern) | Test output formatting | Already used in `run.sh`; keep. |

## Installation

```bash
# Nothing new required for the DEFAULT path — bash + node + jq + shellcheck already assumed.

# OPTIONAL, only if adopting bats for unit-level specs:
git submodule add https://github.com/bats-core/bats-core.git tests/bats
git submodule add https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert
git -C tests/bats checkout v1.13.0

# OPTIONAL, only for `conjure audit --cost --exact` (never bundled):
#   invoked at runtime, never installed into the kit:
npx --yes @anthropic-ai/sdk  # (illustrative; real call is a tiny .mjs using the SDK)
```

The kit's own `package.json` (if any) MUST keep `dependencies: {}` empty. Anything heavier is a `devDependency` at most, or an `npx` runtime call.

## Detailed Findings by Question

### (a) Fixture-based regression testing of POSIX shell CLIs

**Pick: extend the hand-rolled harness; vendor bats-core only if specs get complex.**

The v0.3.0 fixture work is mostly: for each of the 9 profiles, scaffold an example project under `tests/fixtures/<profile>/`, run `conjure audit`, and assert it exits clean with expected files. That is a `for` loop calling the existing `audit-setup.sh` — the current `pass`/`fail`/`t` helpers in `run.sh` already model this perfectly. Adding a framework here buys little and costs a dependency.

When a framework *does* earn its place: testing individual CLI functions in isolation (e.g., "`cmd_init --dry-run` writes zero files", arg-parsing edge cases, telemetry-log format). For those, **bats-core v1.13.0** is the standard:
- Pure bash, runs on bash 3.2+ (matches the POSIX/cross-platform constraint).
- TAP output (CI-friendly, plays with the existing GitHub Actions).
- Installs cleanly as **git submodules** with no npm/runtime footprint.
- `bats-assert`/`bats-support` (v2.2.4) give readable assertions.

**Why bats over shellspec:** shellspec's last release is **0.28.1 from January 2021** — effectively unmaintained for 5 years. bats-core shipped v1.13.0 in **November 2025** with an active org and three maintained helper libs. For a "trust-first" kit, picking the actively-maintained tool matters. shellspec's BDD DSL and broader-shell support are nice but irrelevant here: the kit is bash-targeted, and the maintenance gap is disqualifying.

**Dry-run enforcement as a test target:** the cleanest assertion is *filesystem-snapshot-based* — record `find <target> -type f | sort` before and after `conjure init --dry-run`, assert identical. This is a hand-rolled assertion regardless of framework. The CLI already threads `dryrun` through `cmd_init`/`cmd_migrate`; the gap is that `init-project.sh` and `profiles/*/apply.sh` must honor it. Tests should assert the *snapshot invariant*, not internal flags.

### (b) Lightweight local telemetry from Claude Code hooks (no external service)

**Pick: append-only JSONL written by hooks, parsed by `jq` in `conjure audit`.**

Critical 2026 finding — the Claude Code hooks API now exposes exactly what's needed, so telemetry needs no transcript scraping or external service:

- **`PreToolUse` / `PostToolUse` with `tool_name: "Skill"`** — when Claude invokes a skill (even autonomously, not just via `/slash`), the hook receives `tool_input.skill_name`. This is the primary skill-firing signal.
- **`InstructionsLoaded`** — fires when CLAUDE.md/skills/rules load, with `file_path`, `memory_type`, and `load_reason`. Captures eager-load events for the retire-list signal.
- **`SessionStart`** (`source`, `model`) and **`SessionEnd`/`Stop`** — bracket sessions for per-session aggregation. Common fields `session_id` + `cwd` are on every event.

Implementation: a small hook (bash + mirrored `.mjs`) reads the JSON on stdin, extracts `session_id` + `skill_name` + timestamp, and appends one line to `.claude/telemetry/skills.jsonl`. JSONL is the right format — append-only, crash-safe, `jq`-readable, no DB. `conjure audit --skills` (or a quarterly script) tallies `skill_name` frequency to produce the retire-list ("skills that never fired in N sessions").

Hard rules for the hook (from the existing kit constraints + hooks contract):
- Telemetry hooks MUST `exit 0` and emit nothing on stdout that isn't intended JSON (stdout at exit 0 is parsed by Claude Code). Safest: write the file, then `exit 0` with empty stdout, or set `"suppressOutput": true`.
- MUST be non-blocking and fast (<100ms); never `exit 2` (that blocks the tool — telemetry must never block).
- MUST be append-only and tolerate a missing/locked file (concurrent sessions). Use `>>` with `mkdir -p`.
- Log path under the project's `.claude/` (gitignore it via the existing `.gitignore.tmpl`), never a global or network location. Local-only is a privacy + trust requirement for an OSS kit.

Do NOT: ship an analytics SDK, phone home, use a sqlite dep, or parse the `transcript_path` JSONL (fragile, large, and unnecessary now that `Skill` tool events exist).

### (c) Estimating Claude session token cost from static file sizes

**Pick: chars/4 heuristic × baked-in per-model price table. No tokenizer dependency.**

Verified blocker against bundling a tokenizer: the official **`@anthropic-ai/tokenizer`** npm package is **explicitly inaccurate for Claude 3 and later models** (per Anthropic's own README/npm page) — and the kit targets Claude Code ≥2.1.117 running Claude 4.x. There is **no accurate offline Claude 4 tokenizer** published; the only billing-grade source is the online `messages.countTokens()` API. tiktoken/`gpt-tokenizer` are OpenAI encodings and only approximate Claude.

Given the kit's zero-heavy-dep + offline + cross-platform constraints, the right call is the same heuristic the kit *already documents* in `reference/SIZING.md`: **~4 chars/token**. The cost estimator's job is a *budget warning*, not an invoice — heuristic precision (±10–15%) is more than enough to flag "your harness eagerly loads 30k tokens every session."

Design for `conjure audit --cost`:
1. Sum bytes of eager-loaded harness surface: root `CLAUDE.md` + every skill's `name:`+`description:` frontmatter (only the body loads on match, so count bodies separately as "potential") + agent definitions + `.claude/settings.json` + MCP tool-metadata estimate.
2. `tokens ≈ chars / 4`. Add the documented session baseline (~20k) and MCP metadata (~500–3000/server) from SIZING.md.
3. Multiply by a small price table baked into `conjure` (current rates, May 2026, per 1M tokens):

   | Model | Input | Output |
   |-------|-------|--------|
   | Haiku 4.5 | $1.00 | $5.00 |
   | Sonnet 4.6 | $3.00 | $15.00 |
   | Opus 4.7 | $5.00 | $25.00 |

   Cost is dominated by *input* (the harness is input context), so report input-cost-per-session prominently. Note the 90% prompt-cache discount and 50% batch discount as caveats, not defaults.
4. Offer `--cost --exact` as an opt-in escape hatch that lazily calls `countTokens()` via the SDK *if* credentials exist, else silently falls back to the heuristic with a one-line note.

Keep the price table in one obvious constant block with a "rates as of 2026-05; verify at platform.claude.com/docs/about-claude/pricing" comment, so it's a trivial one-line update — pricing drifts and must not require a code rewrite.

### (d) Cross-platform dependency pre-flight (bash + Windows `.mjs`)

**Pick: `command -v` probe table in bash, mirrored `.mjs` probe, OS-detected install hints.**

The pattern is already half-built in `cli/conjure` `cmd_preflight()` (checks git/jq/rg, suggests `brew install`). v0.3.0 hardens it:

- **Detection:** `command -v <tool>` is the portable POSIX primitive (works in bash, dash, git-bash). In `.mjs`, mirror with `child_process` running `command -v` on POSIX and `where` on Windows, or check `process.platform`. Avoid `which` (not always present; non-POSIX exit semantics).
- **OS-aware install hints:** the current code hardcodes `brew install`. Make it OS-detected: `brew` (macOS), `apt`/`dnf` (Linux), `winget`/`scoop`/`choco` (Windows), `npm i -g` for node tools. Detect via `uname -s` (bash) / `process.platform` (node).
- **One-command fix-it:** print a single copy-pasteable line per platform, e.g. `brew install jq ripgrep` — never auto-run installs (the kit forbids `curl|sh` foot-guns; same principle applies to silent package installs). Print, let the human run it.
- **Required vs optional tiers** (already modeled): hard-require `git`, `jq`; recommend `rg`; optional power tools (`graphify`, `ast-grep`, `gitleaks`, `repomix`) stay advisory and never block.
- **Windows reality:** the `.mjs` hooks are the Windows story. Document that the bash CLI itself expects git-bash/WSL on Windows; the `.mjs` hooks are what run under native PowerShell/cmd. Preflight should detect the bash-vs-native context and point Windows users at the `.mjs` hook variants.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Hand-rolled `run.sh` fixtures | bats-core v1.13.0 | When per-function unit specs (dry-run invariants, arg parsing) outgrow inline `pass`/`fail` helpers. Adopt as a submodule alongside, never replacing the integration loop. |
| bats-core | shellspec 0.28.1 | Essentially never — last release Jan 2021, unmaintained. Only if you needed deep ksh/zsh/dash matrix testing, which this kit does not. |
| chars/4 heuristic | `messages.countTokens()` API (`--exact` opt-in) | When a user wants billing-grade numbers and has API creds. Lazy, flagged, never default (rate-limited, needs network + auth). |
| JSONL + jq telemetry | sqlite / analytics SDK | Never for this kit — violates zero-heavy-dep + local-only + cross-platform constraints. |
| `command -v` probe | `troubleshoot`/`preflight-check` tools | Never — those are Kubernetes/heavyweight; wildly out of scope for a shell kit. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`@anthropic-ai/tokenizer`** | Officially inaccurate for Claude 3+ (kit targets Claude 4.x); adds an npm dep for a wrong answer | chars/4 heuristic (already in SIZING.md) |
| **tiktoken / `gpt-tokenizer`** | OpenAI encodings; only approximate Claude, and pull a WASM/native dep | chars/4 heuristic |
| **shellspec** | Unmaintained since 0.28.1 (Jan 2021); trust-first kit shouldn't depend on abandoned tooling | bats-core v1.13.0 (Nov 2025) |
| **An analytics/telemetry SDK or any phone-home** | Privacy + trust killer for an OSS kit; adds a dep + network | Local append-only JSONL parsed by jq |
| **sqlite for the telemetry store** | Heavy native dep; cross-platform binary headaches; overkill for append+count | JSONL file |
| **Parsing `transcript_path` JSONL for skill detection** | Fragile, large, format-volatile; unnecessary now that `PreToolUse` exposes `tool_name=Skill`/`skill_name` | `PreToolUse` + `InstructionsLoaded` hook events |
| **`which` for detection** | Not guaranteed present; inconsistent exit codes across platforms | `command -v` (bash) / platform-aware probe (`.mjs`) |
| **Auto-running installers in preflight** | Violates the kit's "no `curl\|sh` foot-guns" safety rule | Print one copy-pasteable install command; human runs it |
| **npm `dependencies` in the kit** | Breaks "no hard dependency on heavy runtimes"; forces an install step | stdlib-only `.mjs`; `npx --yes` for rare opt-in paths |

## Stack Patterns by Variant

**If fixture assertions stay simple (audit exit code + file presence):**
- Use hand-rolled `run.sh` loop only. No submodule.
- Because: adding bats for `grep`+exit-code checks is pure overhead.

**If you add fine-grained unit specs (dry-run invariants, telemetry-format, arg parsing):**
- Vendor bats-core + bats-assert as pinned submodules; keep `run.sh` as the integration driver that also invokes `bats tests/unit/`.
- Because: readable assertions + TAP output earn their keep at the unit level.

**If a user needs billing-grade cost numbers:**
- `conjure audit --cost --exact` → lazy SDK `countTokens()` if creds present.
- Because: heuristic is for budgeting; exact mode is for the rare precision case, never the default.

**If running on native Windows (no WSL/git-bash):**
- Use the `.mjs` hook + `.mjs` preflight variants; bash CLI assumes git-bash/WSL.
- Because: native Windows can't run the bash hooks; `.mjs` is the portability layer.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| bats-core v1.13.0 | bash 3.2+ | macOS ships bash 3.2; v1.13.0 supports it. Submodule, no npm. |
| bats-assert v2.2.4 | bats-core v1.x | Requires bats-support; both as submodules (not on npm). |
| shellcheck v0.11.0 | POSIX + bash 5.3 directives | New SC2327–2335 checks; expect a few new lints on fresh telemetry scripts. |
| Node `.mjs` hooks | Node ≥18 LTS, stdlib only | No transitive deps to break. |
| Price table | rates as of 2026-05 | Drifts ~quarterly; keep in one constant block with a verify-at-URL comment. |
| Claude Code hooks API | Claude Code ≥2.1.117 (kit min) | `Skill` tool event + `InstructionsLoaded` confirmed present in current hooks reference. |

## Sources

- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks) — HIGH. Confirmed full event list, `PreToolUse`/`PostToolUse` `tool_name: "Skill"` + `tool_input.skill_name`, `InstructionsLoaded` event, common fields (`session_id`, `cwd`, `transcript_path`), exit-code semantics (0 parses stdout, 2 blocks), JSON output options (`suppressOutput`).
- [bats-core GitHub releases (API)](https://github.com/bats-core/bats-core) — HIGH. v1.13.0 published 2025-11-07; bats-assert v2.2.4 latest tag.
- [ShellSpec releases (API)](https://github.com/shellspec/shellspec) — HIGH. Latest 0.28.1 published 2021-01-11 (unmaintained → disqualified).
- [ShellSpec comparison page](https://shellspec.info/comparison.html) — MEDIUM. Feature comparison (vendor source, treat with caution).
- [bats-core installation docs](https://bats-core.readthedocs.io/en/stable/installation.html) — HIGH. Git-submodule install path; helper libs not on npm.
- [shellcheck releases (API)](https://github.com/koalaman/shellcheck) — HIGH. v0.11.0 (2025-08-03), new SC2327–2335 checks.
- [@anthropic-ai/tokenizer (npm)](https://www.npmjs.com/package/@anthropic-ai/tokenizer) — HIGH. Explicitly "no longer accurate as of Claude 3 models" → do not bundle.
- [Claude API Token counting docs](https://platform.claude.com/docs/en/build-with-claude/token-counting) — HIGH. `countTokens()` is the only billing-grade source; free but rate-limited; ~4 chars/token rule of thumb.
- [Claude API Pricing](https://platform.claude.com/docs/en/about-claude/pricing) — HIGH. Haiku 4.5 $1/$5, Sonnet 4.6 $3/$15, Opus 4.7 $5/$25 per 1M; output 5× input; 90% cache / 50% batch discounts.
- [Conjure `reference/SIZING.md`](reference/SIZING.md) — HIGH (internal). Existing chars/4 token estimates + session baseline (~20k) + MCP metadata (500–3000/server) — reuse directly in the estimator.
- [Conjure `cli/conjure` `cmd_preflight()`](cli/conjure) — HIGH (internal). Existing `command -v` probe + tiered required/optional tools to extend.

---
*Stack research for: Conjure v0.3.0 Testing + telemetry tooling*
*Researched: 2026-05-24*
