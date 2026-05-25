# Pitfalls Research

**Domain:** Open-source init kit for Claude Code (POSIX bash + Node `.mjs` hooks) — v0.3.0 "Testing + telemetry"
**Researched:** 2026-05-24
**Confidence:** HIGH (most pitfalls verified against this repo's own source; external claims verified against named primary sources — GitHub CLI, Next.js, Anthropic token-count endpoint, bats-core docs, nodejs/node issues)

> Scope note: these are pitfalls for the **five v0.3.0 features** — fixture-based shell-CLI tests, dev-tool telemetry, token/cost estimation, `--dry-run` enforcement, cross-platform hooks. Generic "write tests" advice is omitted. Several pitfalls are *already present in the working tree* and are flagged inline with `file:line`.

---

## Critical Pitfalls

### Pitfall 1: `--dry-run` is a lie — partial mutation escapes the guard (already shipping)

**What goes wrong:**
`conjure init --dry-run` parses the flag (`cli/conjure:57`) and prints `dry_run=1` (`cli/conjure:64`) but then calls `bash "$CONJURE_HOME/scripts/init-project.sh" "$mode" "$target"` (`cli/conjure:74`) **with no `DRY_RUN` passed**, and `profiles/<p>/apply.sh "$target" "$dryrun"` only on the `init` path. `scripts/init-project.sh` greps return zero matches for `DRY_RUN`. So `init --dry-run` writes `.claude/`, stamps `.conjure-version` (`cli/conjure:83` runs unconditionally), and applies the profile — real filesystem mutations. Only the 6 `migrations/*/migrate.sh` honor `DRY_RUN` (`migrations/from-claude/migrate.sh:15` et al). The danger pattern: a guard that covers *some* writers convinces users the flag is safe everywhere, so they run it against a populated repo and lose data.

**Why it happens:**
Dry-run was retro-fitted to migrations first, then the flag was exposed on `init` for UX symmetry without threading the env var through `init-project.sh` and the profile/compliance overlays. Each script reads `DRY_RUN` independently (no shared library), so "add dry-run" is N edits and it's easy to miss one.

**How to avoid:**
- Single source of truth: a sourced `scripts/lib/mutate.sh` exposing `mutate_cp`, `mutate_write`, `mutate_mkdir`, `mutate_rm` that all check `DRY_RUN` once and echo `[dry-run] would …`. Forbid raw `cp`/`>`/`mkdir`/`rm` in mutating scripts via a shellcheck-style grep test (see Pitfall 2's enforcement pattern).
- Thread `DRY_RUN` from `cmd_init` into **every** child: `init-project.sh`, `profiles/*/apply.sh`, `compliance/*/apply.sh`, and the version-stamp line.
- Make dry-run *provable*: a fixture test snapshots the target dir, runs `--dry-run`, and asserts the directory tree + mtimes are byte-identical afterward.

**Warning signs:**
`git status` shows changes after a `--dry-run`; the stdout says "dry run" but `.claude/` appears; new mutating scripts added in later phases don't reference the mutate lib.

**Phase to address:** **Dry-run enforcement phase** (must precede or run alongside the fixture suite, because the fixture suite is the thing that *proves* dry-run is honored).

---

### Pitfall 2: Fixtures leak the real `$HOME` / global config / network into tests

**What goes wrong:**
Shell-CLI tests that don't sandbox `HOME`, `XDG_CONFIG_HOME`, `CLAUDE_CONFIG_DIR`, and `PATH` end up reading the developer's real `~/.claude/`, real `git config`, real installed `graphify`/`gitleaks`, or hitting the network. Tests then pass on the author's laptop and fail in CI (or worse, *mutate the developer's real home*). For Conjure specifically: `scripts/audit-setup.sh`, `session-start-context.sh`, and `pre-commit-quality-gate.mjs` all shell out to `git` and tool binaries, so an un-sandboxed fixture run inherits whatever git identity and tools the host happens to have.

**Why it happens:**
bats `setup()`/`teardown()` run per-test but developers forget that env vars persist into the subshells the CLI spawns. The kit's own `tests/run.sh` currently runs in-place against `$CONJURE_HOME` (`tests/run.sh:6-7`) with no `HOME` isolation — fine for static-asset checks, fatal for behavioral fixture runs.

**How to avoid:**
- In `setup()`: `export HOME="$BATS_TEST_TMPDIR/home"; export XDG_CONFIG_HOME="$HOME/.config"; export CLAUDE_CONFIG_DIR="$HOME/.claude"; export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"; mkdir -p "$HOME"`. Set a deterministic git identity (`git config --global user.email test@example.com`).
- Copy fixtures into `BATS_TEST_TMPDIR` and operate there — never run the CLI against the checked-in fixture in place (mutations dirty the repo and break the next test).
- Stub external tools deterministically: prepend a fake-bin dir to `PATH` with shims for `graphify`, `gitleaks`, `npx` so tests don't depend on what's installed and never touch the network.
- Add a teardown leak check: assert the real `~/.claude` mtime is unchanged.

**Warning signs:**
"Passes locally, fails in CI" (or vice-versa); test results vary by which tools the runner has installed; a test author's real git config name appears in fixture output; `.claude.backup-*` dirs accumulate inside `tests/fixtures/`.

**Phase to address:** **Fixture / regression-suite phase** — bake env-sandboxing into the shared `setup()` before writing any per-profile fixture.

---

### Pitfall 3: Telemetry that erodes trust — opt-out, silent, or phones home (the star-killer)

**What goes wrong:**
A developer tool that adds telemetry **opt-out** (on by default) or **silently** triggers community backlash that directly costs the stars/adoption Conjure is explicitly chasing. Precedent is unambiguous: GitHub CLI quietly enabled opt-out telemetry in v2.91.0 with only a buried changelog line → 300+ HN comments in 24h and accusations of GDPR non-compliance (consent must precede processing). Next.js still fields recurring "telemetry violates privacy" issues (vercel/next.js #59686) because it defaults on. Conjure's stated value is *trust before reach* (PROJECT.md: "Adoption depends first on trust … then reach") and its README markets "no `curl | sh` foot-guns" — shipping any data-leaving-the-machine telemetry would be self-contradicting and the worst possible look for a "people-lives-depend-on-it" compliance tool.

**Why it happens:**
"Skill-firing telemetry → retire-list" (ROADMAP.md:39) sounds like product analytics, so it's tempting to implement it like product analytics: a hook that POSTs to a collector. The roadmap word "telemetry" itself primes the wrong mental model.

**How to avoid:**
- **Local-only by design.** The skill-firing telemetry must be a hook that appends to a project-local file (e.g. `.claude/telemetry/skill-firing.jsonl`), never a network call. Document in capital letters: *Conjure telemetry never leaves your machine; there is no collector, no endpoint, no opt-out needed because there is nothing to opt out of.*
- No silent network egress anywhere in a hook. Add a test that greps all hooks for `curl`/`wget`/`fetch`/`http`/`new URL`/socket usage and fails the build if found — turn the trust promise into an enforced invariant.
- Make the local log discoverable and deletable (`conjure audit` should mention it; honor `.claudeignore`/`.gitignore` so it isn't committed by accident → don't leak repo internals).
- If a hosted opt-in ever appears (v0.4.0+ distribution), make it **opt-in with an explicit prompt**, print exactly what's sent, and document the off switch — but keep it out of v0.3.0.

**Warning signs:**
Any hook importing an HTTP client; an "anonymous ID" generated and persisted to `~/`; a config key named `telemetry.enabled: true` default; reviewers asking "where does this data go?"; the word "collector" or "ingest" in a PR.

**Phase to address:** **Skill-firing telemetry phase** — set the local-only/no-egress constraint as a phase success criterion, not an afterthought.

---

### Pitfall 4: Cost estimator uses the wrong tokenizer → misleading numbers users will quote

**What goes wrong:**
`conjure audit --cost` (ROADMAP.md:41) estimates session token cost "from harness size." If it counts tokens with a heuristic (chars/4, `wc -w`) or with `tiktoken` (an OpenAI `cl100k`/`o200k` encoder), the number is wrong for Claude: Claude uses its own tokenizer, and the same text can differ **20–40%** across tokenizers (worse for non-English / code with many symbols). Users will screenshot "Conjure says my harness costs $X/session" and be burned when reality differs — reputational damage for a tool whose whole pitch is rigor and eval-backing.

**Why it happens:**
There is no offline Claude tokenizer library as ubiquitous as `tiktoken`, so the path of least resistance is a char-count heuristic or a borrowed GPT tokenizer. Pricing is also model-version-coupled (per-model $/Mtok, and "harness size" ≠ "session cost" because system reuse, caching, and conversation turns dominate).

**How to avoid:**
- Be explicit about precision: label the output an **order-of-magnitude budget estimate**, show the assumptions (model, $/Mtok, turns assumed), and never imply 2-significant-figure accuracy.
- Decouple from model version: read price + model from a small versioned `pricing.json` (with an "as-of" date) rather than hard-coding; print the date so stale prices are obvious.
- For accuracy when online/opt-in, prefer Anthropic's free `count_tokens` endpoint on a representative sample over any local approximation; fall back to a clearly-labeled char-based estimate offline (so the estimator works with no network, matching the no-phone-home rule above — note these two constraints interact: the *accurate* path needs network, the *default* path must not).
- Estimate the right thing: harness bytes → input tokens *per turn that re-sends them*, not a single number. Document that cost scales with turns, not harness size alone.

**Warning signs:**
A hard-coded `$0.00X` price in a script; `chars / 4` with no caveat; output that doesn't name the model or pricing date; an issue titled "your cost estimate is way off."

**Phase to address:** **Cost-estimator phase** — fix tokenizer choice and the precision-honesty framing in the design, before implementing the number.

---

### Pitfall 5: Cross-platform hooks claimed, but settings wire `bash` only — Windows silently broken (already shipping)

**What goes wrong:**
README.md:58 and PROJECT.md:67 promise "bash hooks for POSIX, Node.js `.mjs` hooks for native Windows," and the `.mjs` files exist (`templates/hooks-nodejs/*.mjs`). But `templates/settings.json.tmpl` hard-codes `bash .claude/hooks/*.sh` for **all four** hook wirings (lines 48, 59, 69, 79). On native Windows without Git Bash, `bash` isn't on PATH → every hook silently no-ops or errors, and the documented Windows story never actually runs. This is a "looks done but isn't": the asset exists, the wiring doesn't. v0.3.0 ("pre-flight dependency verification") is the natural place this gets caught — or shipped broken.

**Why it happens:**
The `.mjs` ports were written as parallel assets but `settings.json.tmpl` was authored once for POSIX and not branched by platform. There's no test asserting the wired command matches an existing, runnable file on the target OS.

**How to avoid:**
- Generate the hook command per platform at `init` time: emit `node .claude/hooks/<name>.mjs "$ARG"` when the kit detects Windows (or always prefer `node` since `.mjs` is the universal path and Node is already a dependency), or emit a `settings.windows.json` variant.
- Inside the `.mjs` hooks, fix the Node cross-platform gotchas that *will* bite: `execSync('git …')` works because Node finds `git.cmd`/`git.exe` on Windows only when `shell:true` or via PATHEXT — verify `git rev-parse` actually resolves on Windows (cross-spawn-style handling), and never build paths by string concat — use `path.join`/`path.sep`. `post-edit-format.mjs:23` already branches `where` vs `command -v` (good); apply the same discipline everywhere.
- Add a test: parse `settings.json.tmpl`, extract each hook command's referenced file, assert it exists and is the right runtime for the target; run the `.mjs` hooks under Node on a Windows CI runner (GitHub Actions `windows-latest`).
- bash `stat` portability: `session-start-context.sh:20` uses `stat -f %m || stat -c %Y` (BSD/GNU) — neither exists on Windows; the `.mjs` `statSync().mtimeMs` is the correct cross-platform form, reinforcing "wire .mjs on Windows."

**Warning signs:**
No `windows-latest` job in CI; Windows users report "hooks don't fire / nothing happens"; any path built with `+ '/'`; `stat -f`/`stat -c` in a script expected to run on Windows.

**Phase to address:** **Pre-flight dependency verification phase** (detect `node` vs `bash`, wire accordingly) + the **fixture/regression phase** (add a Windows CI matrix leg).

---

### Pitfall 6: Flaky fixtures from time, ordering, randomness, and absolute paths

**What goes wrong:**
Fixture assertions that depend on wall-clock (`session-start-context` graph-age math, `.claude.backup-$(date +%Y%m%d-%H%M%S)` names), on git state (commit count / branch), on tool versions (gitleaks output format), or on absolute paths (`$CONJURE_HOME`, `/Users/...`) flake intermittently or fail on a clean checkout. Backup-dir timestamps in particular make output non-deterministic and can collide within the same second.

**Why it happens:**
Shell glue naturally reaches for `date`, `pwd`, and host git state. A fixture authored at one moment encodes that moment.

**How to avoid:**
- Freeze nondeterminism: inject a fixed clock where age math happens (env override for "now"), or assert on *ranges*/*shape* not exact values. For backup names, assert the glob `.claude.backup-*` matches one dir, not a literal name.
- Normalize output before diffing: strip absolute paths to `<CONJURE_HOME>`, redact timestamps, sort lists. Compare normalized golden files.
- Init a deterministic git repo inside each fixture in `setup()` (fixed author, one commit) so any `git`-reading code path is stable.
- Mark each test independent; never rely on a prior test having created state (bats runs may parallelize).

**Warning signs:**
A test that passes on re-run but failed once ("heisentest"); golden files containing `/Users/<name>/` or a date; failures only at second boundaries / only in fast CI.

**Phase to address:** **Fixture / regression-suite phase.**

---

### Pitfall 7: "Audited green" fixtures rot silently against schema/cap changes

**What goes wrong:**
The plan ships "one example project per stack profile, audited green" (PROJECT.md:43). If a fixture is generated once and committed, later changes to size caps, JSON schemas, or anti-pattern rules can make the *fixtures themselves* stale — but a regression suite that only asserts "audit exits 0" won't notice a fixture that should now warn, and a fixture frozen as a golden file masks a real audit regression as a "fixture needs updating" chore.

**Why it happens:**
Fixtures serve two conflicting roles: (a) realistic inputs to exercise the CLI, and (b) golden expected outputs. When the kit's rules evolve, both move and it's unclear which is the source of truth.

**How to avoid:**
- Separate "input fixtures" (hand-authored, intentionally varied: one clean, one over-cap, one with `@import`, one with `exit 1` hook) from "expected audit verdicts" (per-fixture assertion of exit code + specific findings). Assert *specific* findings ("flags CLAUDE.md >100"), not just exit status — encode the FAILURE-MODES.md catalog as fixtures (ROADMAP.md:42 "failure-mode reproductions as tests").
- Regenerate-and-diff workflow: a `make update-fixtures` that re-emits golden audit output, so rule changes produce a reviewable diff instead of silent rot.
- At least one fixture must intentionally fail audit, proving the suite can detect breakage (a suite where everything is green can't catch a regression that makes everything green).

**Warning signs:**
Every fixture asserts exit 0; updating a cap requires editing many golden files with no visible intent; audit regressions discovered by users, not the suite.

**Phase to address:** **Fixture / regression-suite phase** + **failure-mode-reproduction phase.**

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Per-script `DRY="${DRY_RUN:-0}"` copy-pasted (current state) | No shared lib to build | Every new mutating script can silently skip the guard (Pitfall 1) | Never for new scripts once a `mutate` lib exists |
| `chars/4` token estimate with no caveat | Ships cost estimator offline, fast | Users quote wrong numbers; trust hit (Pitfall 4) | Only if labeled "rough estimate" + assumptions printed |
| Hard-coded `bash …` in settings template (current state) | Single template, no branching | Windows hooks silently dead (Pitfall 5) | Never — prefer `node …` (universal) |
| Telemetry as a POST to a collector | "Real" analytics, central dashboard | Trust collapse, GDPR exposure, lost stars (Pitfall 3) | Never in v0.3.0; only opt-in + disclosed later |
| Running tests in-place against `$CONJURE_HOME` (current `tests/run.sh`) | Zero setup | Behavioral fixtures leak real $HOME / dirty the repo (Pitfall 2) | OK for static-asset checks only |
| Golden file = "whatever audit emits today" | Fast to capture | Masks regressions as "fixture needs update" (Pitfall 7) | Only with regenerate-and-diff + ≥1 intentional-fail fixture |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `git` from `.mjs` hooks | Assume `execSync('git …')` resolves on Windows | Confirm via PATHEXT / cross-spawn behavior; handle empty output gracefully (already wrapped in try/catch — keep that) |
| `gitleaks`/`graphify`/`npx` in tests | Depend on host-installed version & output format | PATH-shim fakes in fixtures; never touch network; `command -v … || skip` |
| Anthropic token counting | Use OpenAI `tiktoken` for Claude cost | Use Anthropic `count_tokens` endpoint for accuracy (opt-in/online); labeled char heuristic offline |
| Claude Code `settings.json` hooks | Wire `bash` only; assume Git Bash present | Wire `node .mjs` (universal) or branch by detected OS at init |
| `stat` for file mtime in bash | `stat -f`/`stat -c` (no Windows form) | Prefer the `.mjs` `statSync().mtimeMs` path on non-POSIX |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Telemetry hook does file I/O / locking on every skill load | Session sluggish; >2s hook timeout (FAILURE-MODES.md "Hook timeout") | Append-only `jsonl`, no fsync, no lock; keep <2s budget | Sessions firing many skills rapidly |
| Cost estimator shells out per-file to a tokenizer | `audit --cost` slow on big harnesses | Batch; cache by file hash; estimate, don't tokenize every run | Monorepo with many nested CLAUDE.md |
| Fixture suite copies large trees per test | CI minutes balloon | `setup_file()` for shared expensive setup; minimal fixtures | One fixture per 9 profiles × many tests |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Telemetry log captures file contents / paths / prompts | Leaks repo internals; privacy violation | Log only skill *names* + timestamps; document the schema; default-gitignore the log |
| Network egress from any hook | Silent data exfiltration; contradicts "no curl\|sh" promise | Build-time test greps hooks for http/socket usage and fails (Pitfall 3) |
| Cost estimator sends harness content to a remote tokenizer without consent | Phones home with possibly sensitive prompt text | Offline by default; online token-count is opt-in + disclosed |
| Dry-run leaves a backup or version stamp behind | "Read-only" op mutates disk (Pitfall 1) | Guard *all* writes incl. `.conjure-version` stamp |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| `--dry-run` prints "dry run" but mutates | User trusts it, loses data | Make output truthful; prefix every would-be write with `[dry-run]` |
| Cost number with no model/date/assumptions | User quotes it, gets burned | Always print model, $/Mtok, as-of date, "estimate" label |
| Telemetry with no visible off-switch / location | "Is this thing spying on me?" | Document local-only loudly; show path in `conjure audit` |
| Pre-flight fix-it suggests wrong installer per OS | Windows user gets a `brew`/`apt` command | Detect OS; emit the matching one-command install |

## "Looks Done But Isn't" Checklist

- [ ] **`conjure init --dry-run`:** Often still writes `.claude/`, profile overlay, and `.conjure-version` — verify `git status` is clean after a dry-run on a populated fixture.
- [ ] **Cross-platform hooks:** `.mjs` files exist but `settings.json.tmpl` wires `bash` only — verify the wired command references a runtime present on the target OS; add a `windows-latest` CI leg.
- [ ] **Telemetry:** "Local-only" claimed — verify no hook contains `curl`/`fetch`/`http`/socket; verify the log path is gitignored and contains no file contents.
- [ ] **Cost estimator:** "Predicts cost" — verify it names the model + pricing date and is labeled an estimate; verify it doesn't silently phone home.
- [ ] **Fixtures:** "Audited green" — verify at least one fixture intentionally *fails* audit, and assertions check specific findings not just exit 0.
- [ ] **Fixture isolation:** Verify `setup()` sandboxes `HOME`/`XDG_CONFIG_HOME`/`CLAUDE_CONFIG_DIR` and a fresh checkout passes with no global tools installed (or with deterministic shims).
- [ ] **Pre-flight verify:** "One-command install fix-its" — verify the suggested command matches the detected OS/package manager.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Dry-run mutated a real repo | MEDIUM | Restore from `.claude.backup-*` (FAILURE-MODES "Disaster recovery"); add the missing guard + a proving test before reshipping |
| Telemetry shipped opt-out/phoning home | HIGH (reputational) | Immediately patch to local-only or remove; public changelog + apology; add no-egress build test. Stars lost are hard to win back |
| Cost numbers quoted wrong publicly | MEDIUM | Re-label as estimate, add assumptions, ideally switch to count_tokens; correct docs |
| Windows hooks dead in the field | LOW–MEDIUM | Ship `node .mjs` wiring patch; add windows CI so it can't regress |
| Flaky fixture in CI | LOW | Normalize output / inject fixed clock / sandbox env; quarantine then fix root cause (don't add retries as a permanent fix) |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Dry-run partial mutation | Dry-run enforcement (before/with fixtures) | Fixture asserts target tree + mtimes unchanged after `--dry-run` |
| 2. Fixtures leak real $HOME | Fixture / regression suite | Clean-checkout CI passes with no global tools; teardown leak check on `~/.claude` |
| 3. Telemetry erodes trust | Skill-firing telemetry | Build test: no http/socket in any hook; log is local + gitignored + names-only |
| 4. Wrong-tokenizer cost | Cost estimator | Output names model + pricing date + "estimate"; offline default has no network |
| 5. Bash-only hook wiring | Pre-flight dep verify (+ fixture phase CI) | `settings` references runtime present on OS; `windows-latest` job runs `.mjs` hooks green |
| 6. Flaky fixtures | Fixture / regression suite | Suite green on 3 consecutive reruns; golden files contain no abs paths/timestamps |
| 7. Fixture rot / green-only suite | Fixture + failure-mode-repro phases | ≥1 intentional-fail fixture; assertions check specific findings |

## Sources

- This repository (HIGH — primary): `cli/conjure:51-107`, `scripts/init-project.sh` (no `DRY_RUN`), `migrations/*/migrate.sh:15`, `templates/settings.json.tmpl:48-79`, `templates/hooks-nodejs/*.mjs`, `templates/hooks/session-start-context.sh:20`, `tests/run.sh:6-7`, `FAILURE-MODES.md`, `PROJECT.md`, `planning/ROADMAP.md`.
- [GitHub CLI Silently Enables Telemetry: Opt-Out Is Wrong — byteiota](https://byteiota.com/github-cli-silently-enables-telemetry-opt-out-is-wrong/) (MEDIUM — corroborates GDPR/consent + backlash scale)
- [Telemetry violates user privacy · vercel/next.js #59686](https://github.com/vercel/next.js/issues/59686) and [#59688](https://github.com/vercel/next.js/issues/59688) (MEDIUM — recurring opt-out backlash)
- [opt-out telemetry from cli tools — revathskumar](https://blog.revathskumar.com/2026/01/opt-out-telemetry-from-cli-tools.html) (LOW–MEDIUM — community sentiment)
- [How to Count Tokens and Estimate LLM Costs — ML Journey](https://mljourney.com/how-to-count-tokens-and-estimate-llm-costs-before-you-ship/) and [tokencost · PyPI](https://pypi.org/project/tokencost/) (MEDIUM — tiktoken ≠ Claude; per-model drift 20–40%; use provider count_tokens)
- [Writing tests — bats-core docs](https://bats-core.readthedocs.io/en/stable/writing-tests.html) and [Testing Bash Scripts with BATS — HackerOne](https://www.hackerone.com/blog/testing-bash-scripts-bats-practical-guide) (MEDIUM — HOME/XDG/PATH isolation, setup/teardown, `command -v … || skip`)
- [Tips for Writing Portable Node.js Code — domenic gist](https://gist.github.com/domenic/2790533), [cross-spawn — npm](https://www.npmjs.com/package/cross-spawn), [Cannot spawn shell script if path has spaces · nodejs/node #38490](https://github.com/nodejs/node/issues/38490) (MEDIUM — Windows .cmd/.exe, path.sep, spawn shell gotchas)

---
*Pitfalls research for: open-source Claude Code init kit (bash + Node) — v0.3.0 Testing + telemetry*
*Researched: 2026-05-24*
