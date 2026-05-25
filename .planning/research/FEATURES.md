# Feature Research

**Domain:** Open-source developer tooling / AI-coding-harness init kit (Conjure v0.3.0 "Testing + telemetry")
**Researched:** 2026-05-24
**Confidence:** HIGH (telemetry, adoptability, dry-run, golden tests verified across multiple current sources incl. the April-2026 GitHub CLI telemetry backlash; cost-estimation accuracy MEDIUM — heuristic-vs-tokenizer numbers are well-sourced but Claude's exact tokenizer is not publicly published)

This file covers two intertwined questions for the milestone:
1. **v0.3.0 feature set** — test fixtures/regression, skill telemetry, cost estimator, dry-run, pre-flight deps.
2. **OSS adoptability** — what actually earns trust and moves stars.

Telemetry privacy stance is made **explicit** (see the boxed stance under Anti-Features).

---

## Feature Landscape

### Table Stakes (Users Expect These)

Missing these = the tool feels untrustworthy or unfinished, and developers (the exact audience that scrutinizes dev tools hardest) walk away.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Telemetry OFF by default; explicit opt-in** | The April-2026 GitHub CLI opt-out telemetry rollout drew 419 pts / 302 comments on HN in 24h. Developers expect CLIs to be silent unless told otherwise. Opt-out = trust collapse. | LOW (a no-op default + an enable flag) | The single highest-trust-risk decision in the milestone. Conjure's PROJECT.md "Skill-firing telemetry" must default to **local-only**, never network. See boxed stance below. |
| **Telemetry is local-only / no network egress** | "Anonymous telemetry" only lands with devs if they can verify the claim. The safest verifiable claim is *nothing leaves the machine*. Local-only sidesteps the entire GDPR/HIPAA-egress problem that bit `gh`. | LOW–MEDIUM | Write to `.claude/telemetry/*.jsonl` (git-ignored). This is a perfect fit: the use case is a *local* retire-list signal, not a vendor dashboard. No phone-home = no consent prompt drama. |
| **`DO_NOT_TRACK` + env-var + config honored** | De-facto standard convention (`DO_NOT_TRACK=1`, plus a tool-specific `CONJURE_TELEMETRY=off` and `conjure config`). Multiple opt-out surfaces is a documented best practice. | LOW | Even for local-only telemetry, honoring `DO_NOT_TRACK` signals good citizenship and pre-empts the "is this thing watching me" reflex. |
| **Documented telemetry schema + user-inspectable payload** | Transparency is the #1 telemetry best practice. Devs trust telemetry only if they can read exactly what is recorded. `gh`'s vagueness ("are flag values sent?") was a top complaint. | LOW | Ship a `TELEMETRY.md` listing every field; add `conjure telemetry show` to print the local log. Since it's local JSONL, "inspect" is just `cat`. |
| **No PII / no secrets / no file contents in any recorded event** | Non-negotiable. The classic trap is "track everything" → accidentally capturing tokens, paths, repo names, command args. | LOW (by *not* collecting) | Record only: skill name, load count, session id (random, local), Conjure version, timestamp bucket. Never: repo path, file contents, command args, env. |
| **Test fixtures: one audited-green example project per stack profile** | Already an Active requirement. A tool that scaffolds 9 profiles but tests none reads as unverified. Fixtures are the credibility proof for the audit engine. | MEDIUM | `tests/fixtures/<profile>/` each runnable through `conjure audit` → assert green. Golden/snapshot pattern: capture known-good audit output, diff on every run. |
| **Regression suite runnable in one command + in CI** | `tests/run.sh` is already advertised (112 tests). v0.3.0 extends it to per-fixture audit assertions. CI gating on every PR is table stakes for a "production-grade" claim. | MEDIUM | Golden-file convention: baselines stored on disk git-diffably, with PR-based approval to update. Normalize/scrub dynamic data (timestamps, tmp paths) to avoid platform noise. |
| **`--dry-run` that genuinely mutates nothing, everywhere** | Active requirement ("enforced everywhere; not just accepted as a flag"). For a tool whose core value is "trustworthy one command," a dry-run that secretly writes is a credibility killer. | MEDIUM | Model on `terraform plan`: safe to re-run, previews exact changes, no mutation APIs called. Print the diff/plan of files that *would* change. Must cover init, migrate, and overlays. |
| **Pre-flight dependency verification with actionable fix-its** | Active requirement. A scaffolder that fails opaquely when `jq`/`node`/`gitleaks` is missing feels broken. Devs expect "here's what's missing and the exact install command." | LOW–MEDIUM | Already partly present ("Pre-flight checks for tool availability"). v0.3.0 upgrade = one-command fix-its (e.g. `brew install jq`). Never auto-install silently. |
| **Quickstart that works in <60s + copy-pasteable** | Documented: if a dev can't grok what a tool does / how to start in ~30s, they pick an alternative. README already has a Quickstart; fixtures make it *demonstrably* true. | LOW | The fixtures double as a quickstart proof: "here's a real repo it produces, audited green." |
| **Standard repo hygiene (LICENSE, CONTRIBUTING, SECURITY, COC, issue templates)** | Core trust signals; already shipped. Their *presence* is table stakes, not a differentiator. | DONE | Conjure already has all of these. Maintain, don't expand. |
| **CI/build-status + test badges that are real** | Badges are the at-a-glance health signal. But a hardcoded "112 passing" badge that drifts from reality erodes trust. | LOW | README already has CI + a *static* "tests-112" badge. v0.3.0 should make the test badge dynamic (CI-generated) so it never lies. |

### Differentiators (Competitive Advantage)

These align with Conjure's Core Value ("a trustworthy command that keeps a harness healthy over time") and the maintainer's stars/adoption goal. Don't try to differentiate on everything — these are the few that compound.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Local-only skill-firing telemetry → quarterly "retire-list" signal** | This is genuinely novel and on-brand: privacy-respecting telemetry whose *only* output is helping you prune dead skills. Turns the dreaded "telemetry" word into a trust *asset* ("the telemetry tool that never phones home"). | MEDIUM | The differentiator is the framing + the local-only stance, not the recording itself. Tie to the eval-backed "less context = better adherence" thesis: telemetry that *reduces* your harness. |
| **`conjure audit --cost` token/cost estimator** | No comparable harness kit (awesome-toolkit, plugin-template, TemplateClaw) estimates the token cost of the harness you're about to ship. Directly serves the "less context" philosophy with a number. | MEDIUM | Accuracy bar below. Frame as a *budget/planning* number, not a billing guarantee. Pairs with SIZING.md. |
| **Failure-mode reproductions encoded as tests** | FAILURE-MODES.md already documents breakages; turning each into an executable regression test is a strong "we don't just document bugs, we guard against them" signal. Very few scaffolders do this. | MEDIUM | Each FAILURE-MODES.md entry → a fixture that reproduces the symptom + asserts audit catches it. Self-reinforcing docs↔tests loop. |
| **Honest COMPARISON.md (already exists) kept current** | Comparison docs are a documented star-driver: they answer "why this over X" without the reader doing the research. Conjure's is unusually honest ("when NOT to use Conjure"), which *builds* trust. | LOW | Maintain it. Add a row/section once v0.3.0 ships (cost estimate + local telemetry are unique vs every listed competitor). |
| **An animated terminal demo (asciinema → GIF) in README** | Documented as one of the highest-leverage first-impression / adoption moves: a 3-second GIF beats 10 paragraphs. Conjure's CLI has colored audit output — ideal for a demo. README currently has *no* demo. | LOW | Record `conjure init` + `conjure audit` (green) with asciinema, convert with `agg`. Highest ROI adoption item for the effort. Belongs in the milestone even though it's "docs." |
| **Reproducible, eval-backed numbers turned into a visible badge/section** | The "112 self-tests" + size-cap story is already a differentiator vs catalog-style competitors. v0.3.0's fixtures make it auditable by anyone (`git clone && bash tests/run.sh`). | LOW | "Clone and verify in one command" is itself a trust signal stronger than any badge. |

### Anti-Features (Commonly Requested, Often Problematic)

> ### Telemetry Privacy Stance (explicit)
> **Conjure telemetry MUST be: off-by-default, opt-in, local-only (zero network egress), PII-free, and user-inspectable.**
> The skill-firing telemetry's purpose is a *local* retire-list signal — there is no product reason to transmit anything. Any future "phone home" requires (a) off-by-default, (b) a first-run consent prompt, (c) a published schema *before* collection, (d) CI/agent contexts exempt by default, and (e) a build-time disable flag. Absent all five, do not build it. The GitHub CLI v2.91.0 opt-out rollout is the cautionary tale: silent defaults + lagging docs + no automation carve-out = trust collapse, even with good intentions and 1% sampling.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Phone-home / network telemetry (even "anonymous")** | "We'd learn how people use it"; vendor-dashboard envy. | Direct trust killer for a dev tool whose pitch is safety/auditability. Creates GDPR/HIPAA egress exactly where Conjure's compliance overlays promise the opposite. Persistent device IDs build longitudinal profiles even at "1% sampling." | Local-only JSONL the user owns and can delete. If aggregate insight is ever wanted, ask users to *paste* their local report into a Discussion — opt-in by construction. |
| **Opt-out telemetry (on by default, disable later)** | "Maximizes data collected." | The exact pattern that detonated for `gh`. Ephemeral CI containers can't persist a disable config, so "opt-out" silently re-enables in automation. | Opt-in only. Even local-only stays off until `conjure telemetry enable`. |
| **Auto-installing missing dependencies** | "Make pre-flight friendlier — just fix it for me." | Violates Conjure's "read every script before running / no `curl \| sh` foot-guns" stance. Silent installs are a supply-chain and surprise-mutation risk. | Pre-flight *prints* the exact one-command fix-it; the human runs it. Optionally `--print-install` to emit a copy-paste block. |
| **Tokenizer-exact "guaranteed" cost numbers** | "Tell me precisely what this session will cost." | Claude's tokenizer isn't publicly published; session cost depends on runtime conversation, not just harness size. A precise-looking number you can't honor erodes trust when the bill differs. | Ship a *heuristic estimate* with a stated ±band (see accuracy bar). Label it "harness static-cost estimate," not "session cost." |
| **Chasing star count via Product-Hunt blasts / star-exchange** | "Stars = adoption = credibility." | Documented fake-star networks (≈6M suspected fake stars on GitHub) mean savvy devs discount raw counts and look at issues/PRs/release cadence. Gaming it can backfire reputationally. | Earn stars with the demo GIF, honest COMPARISON, clone-and-verify tests, and responsive issues. Sustainable signals over vanity metrics. |
| **A web dashboard / GUI to "visualize telemetry"** | "See trends across repos." | Pulls toward exactly the network-egress + scope-creep the milestone defers (backlog item). Contradicts local-only stance. | Out of scope (already backlog). Keep telemetry a local file + a `telemetry show` summary. |
| **Always-on regenerated golden files (auto-accept on diff)** | "Stop tests breaking on every change." | Auto-accepting snapshots defeats the regression guarantee — drift slips in silently. | PR-based approval to update goldens (`UPDATE_GOLDENS=1` locally, reviewed in the diff). Never auto-update in CI. |

---

## Feature Dependencies

```
[Test fixtures per profile]
    └──required-by──> [Regression suite (tests/run.sh audit assertions)]
                          └──required-by──> [Failure-mode reproductions as tests]
                          └──enables─────> [Dynamic "tests passing" badge]
                          └──enables─────> [Clone-and-verify trust signal]

[--dry-run enforced everywhere]
    └──required-by──> [Safe demo recording (asciinema)]   (record without fear of mutation)
    └──verified-by──> [Regression suite]                  (a test asserts dry-run mutates nothing)

[Pre-flight dependency verification]
    └──enhances────> [Quickstart works <60s]              (clear failure → fast recovery)

[Skill-firing telemetry hook (local-only)]
    └──produces────> [Quarterly retire-list signal]
    └──documented-by─> [TELEMETRY.md schema]  (MUST exist before/with the hook)
    └──inspected-by──> [`conjure telemetry show`]

[Cost estimator (audit --cost)]
    └──reuses──────> [Audit size-cap line counting]       (already counts lines/sizes)
    └──aligns-with──> [SIZING.md token budgets]

[asciinema demo GIF] ──enhances──> [README first impression / adoption]
[Honest COMPARISON.md] ──enhances──> [adoption]  (answers "why this over X")

[Phone-home telemetry] ──conflicts──> [Local-only stance] ──conflicts──> [Compliance overlays]
```

### Dependency Notes

- **Regression suite requires fixtures:** the suite's assertions run `conjure audit` against each fixture; no fixtures = nothing to assert. Fixtures must land first in the phase.
- **Failure-mode tests require the suite:** they are additional fixtures/assertions plugged into the same harness; build the runner before encoding reproductions.
- **`--dry-run` is verified by the suite:** add an explicit test asserting that a dry-run leaves the fixture tree byte-identical (mutation = test fail). This closes the "flag accepted but not enforced" gap noted in ROADMAP.
- **Telemetry schema doc must precede/accompany the hook:** the `gh` lesson — docs lagging implementation = "assume the worst." Ship `TELEMETRY.md` in the same PR as the recording hook, not after.
- **Cost estimator reuses existing line/size counting:** the audit already enforces caps by counting; `--cost` is largely a multiplier + ±band on data the audit already has. Low incremental cost.
- **Phone-home conflicts with compliance overlays:** HIPAA/GDPR overlays promise to *reduce* non-compliant output; undisclosed egress would directly contradict the kit's own positioning. This makes local-only not just nice-to-have but architecturally required.

---

## MVP Definition

(MVP here = the v0.3.0 milestone scope — "minimum to credibly claim production-ready + earn trust.")

### Launch With (v0.3.0)

- [ ] **Test fixtures per stack profile, audited green** — proves the audit engine on real trees; foundation for everything else.
- [ ] **`tests/run.sh` per-fixture audit assertions (golden-file pattern)** — the regression backbone; clone-and-verify trust signal.
- [ ] **`--dry-run` enforced everywhere + a test asserting zero mutation** — closes a known gap; core to the "trustworthy command" value.
- [ ] **Local-only, opt-in, PII-free skill-firing telemetry + `TELEMETRY.md` + `conjure telemetry show`** — the differentiator, done the trust-preserving way.
- [ ] **`conjure audit --cost` heuristic estimator with stated ±band** — cheap, on-thesis, unique vs competitors.
- [ ] **Pre-flight dependency verification with one-command fix-its (no auto-install)** — removes the most common silent-failure.
- [ ] **Failure-mode reproductions encoded as tests** — turns docs into guarantees.
- [ ] **asciinema → GIF demo in README** — highest-ROI adoption move; safe to record once dry-run is enforced.

### Add After Validation (v0.3.x / early v0.4.0)

- [ ] **Dynamic CI-generated test-count badge** — once the suite is stable, stop hardcoding "112."
- [ ] **`--print-install` block for pre-flight** — copy-paste all missing deps at once, after the basic fix-its prove useful.
- [ ] **Per-profile cost rows in SIZING.md** — once the estimator is calibrated against real harnesses.

### Future Consideration (v0.4.0+ / deferred per PROJECT.md)

- [ ] **Distribution (Marketplace, Homebrew, Docker)** — explicitly deferred; reach after trust. Adoption-relevant but out of this milestone.
- [ ] **Any aggregate telemetry** — only via opt-in *paste-your-local-report*, never auto-transmit. Likely never.
- [ ] **Web dashboard / GUI** — backlog; conflicts with local-only stance.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Test fixtures per profile | HIGH | MEDIUM | P1 |
| Regression suite (golden assertions) | HIGH | MEDIUM | P1 |
| `--dry-run` enforced + mutation-zero test | HIGH | MEDIUM | P1 |
| Local-only opt-in telemetry + schema doc | HIGH | MEDIUM | P1 |
| Pre-flight deps + fix-its | HIGH | LOW | P1 |
| asciinema demo GIF in README | HIGH | LOW | P1 |
| `audit --cost` estimator (±band) | MEDIUM | MEDIUM | P2 |
| Failure-mode reproductions as tests | MEDIUM | MEDIUM | P2 |
| Dynamic test-count badge | MEDIUM | LOW | P2 |
| `conjure telemetry show` inspector | MEDIUM | LOW | P2 |
| Keep COMPARISON.md current | MEDIUM | LOW | P2 |
| `--print-install` aggregate fix-it | LOW | LOW | P3 |

**Priority key:** P1 = must have for the milestone; P2 = should have, add when possible; P3 = nice to have.

---

## Cost-Estimation Accuracy Bar ("good enough")

- **Heuristic (chars/4, or a Claude-family-calibrated chars-per-token ratio) lands within ~5–15% of a real tokenizer for English prose** — accurate enough for *budget/planning*, not billing. (MEDIUM confidence: well-sourced for English; Claude uses a SentencePiece-style BPE that differs from OpenAI's tiktoken, and Anthropic's exact tokenizer isn't public.)
- **Recommendation:** ship the heuristic with an explicit ±band and label it a *static harness-cost estimate* (what the always-loaded context costs), not a session-cost guarantee. Optionally note that Anthropic's token-counting API gives exact counts for users who want them.
- **Anti-feature reminder:** do NOT present a single precise number as authoritative — that's the trap that erodes trust when real bills differ.

---

## Competitor Feature Analysis

| Feature | awesome-claude-code-toolkit | claude-code-plugin-template | TemplateClaw / CCHub | Conjure's Approach |
|---------|------------------------------|------------------------------|----------------------|--------------------|
| Test fixtures / regression suite | Catalog, not validated as a suite | Plugin-author tests | UI/desktop focus | Per-profile fixtures + golden audit assertions, CI-gated |
| Telemetry | None / N/A | None / N/A | N/A | **Local-only, opt-in, PII-free** (unique stance) |
| Cost/token estimation | None | None | None | **`audit --cost` heuristic** (unique) |
| Dry-run safety | N/A | N/A | N/A | Enforced everywhere + tested |
| Pre-flight deps | Manual | Manual | N/A | Verified + one-command fix-its |
| Adoption assets | High star count (catalog appeal) | Template appeal | UI appeal | Honest COMPARISON + clone-and-verify + demo GIF + eval-backed numbers |

---

## Sources

Telemetry behavior, opt-in defaults, PII, schema transparency:
- [6 telemetry best practices for CLI tools — Massimiliano Marcon](https://marcon.me/articles/cli-telemetry-best-practices/) (MEDIUM)
- [GitHub CLI v2.91.0 Turns On Default Telemetry — Groundy](https://groundy.com/articles/github-cli-v2910-turns-on-default-telemetry-what-gh-collects-and-how-to-opt-out/) (HIGH — detailed, recent, cautionary tale)
- [GitHub CLI: Opt-out usage telemetry — GitHub Changelog](https://github.blog/changelog/2026-04-22-github-cli-opt-out-usage-telemetry/) (HIGH — primary source)
- [GitHub CLI begins collecting client-side telemetry — The Register](https://www.theregister.com/2026/04/22/github_opts_all_cli_users/) (MEDIUM)
- [GitHub CLI Silently Enables Telemetry: Opt-Out Is Wrong — byteiota](https://byteiota.com/github-cli-silently-enables-telemetry-opt-out-is-wrong/) (LOW — opinion, corroborates backlash)
- [Next.js Telemetry — Vercel](https://nextjs.org/telemetry) (HIGH — opt-out-with-disclosure reference)
- [How to disable telemetry for various OSS tools — makandra](https://makandracards.com/makandra/624560-disable-telemetry-various-open-source-tools-libraries) (MEDIUM — DO_NOT_TRACK / env-var conventions)

Test fixtures / golden / snapshot regression:
- [Golden Tests — Tom Sydney Kerckhove (Medium)](https://medium.com/casperblockchain/golden-tests-e521077ae235) (MEDIUM)
- [Why Snapshot Testing Is the Secret Weapon for API Stability — DEV](https://dev.to/kreya/why-snapshot-testing-is-the-secret-weapon-for-api-stability-4797) (MEDIUM)
- [golden — Go snapshot-testing library (GitHub)](https://github.com/franiglesias/golden) (MEDIUM — convention reference)

Dry-run safety:
- [terraform plan command reference — HashiCorp](https://developer.hashicorp.com/terraform/cli/commands/plan) (HIGH — canonical dry-run/plan model)
- [Terraform Dry Run Explained — Spacelift](https://spacelift.io/blog/terraform-dry-run) (MEDIUM)

Cost / token estimation accuracy:
- [How to Count Tokens and Estimate LLM Costs — ML Journey](https://mljourney.com/how-to-count-tokens-and-estimate-llm-costs-before-you-ship/) (MEDIUM)
- [tokenx — fast token estimation at 96% accuracy (GitHub)](https://github.com/johannschopplich/tokenx) (MEDIUM)
- [Calculating LLM Token Counts: A Practical Guide — Winder.ai](https://winder.ai/calculating-token-counts-llm-context-windows-practical-guide/) (MEDIUM)

OSS adoptability / trust signals / README:
- [Trust Signals in Open Source Projects — HackerNoon](https://hackernoon.com/the-signs-of-a-great-open-source-project) (MEDIUM)
- [How to Write A 4000-Stars GitHub README — Daytona](https://www.daytona.io/dotfiles/how-to-write-4000-stars-github-readme-for-your-project) (MEDIUM)
- [Enhance Your Readme With Asciinema — César Soto Valero](https://www.cesarsotovalero.net/blog/enhance-your-readme-with-asciinema.html) (MEDIUM)
- [Make your README stand out with animated GIFs/SVGs — DEV](https://dev.to/brpaz/make-your-project-readme-file-stand-out-with-animated-gifs-svgs-4kpe) (MEDIUM)
- [How to Write a Good README 2026 — Kunal Ganglani](https://www.kunalganglani.com/blog/write-good-readme-guide) (LOW — corroborates 30-second rule)

---
*Feature research for: open-source AI-coding-harness init kit (Conjure v0.3.0)*
*Researched: 2026-05-24*
