---
phase: 06-cost-estimator
verified: 2026-05-25T00:00:00Z
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
---

# Phase 06: Cost Estimator Verification Report

**Phase Goal:** `conjure audit --cost` gives an honest, offline-by-default estimate of per-session harness token cost without false precision
**Verified:** 2026-05-25
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `lib/prices.json` exists with three models (Haiku 4.5, Sonnet 4.6, Opus 4.7) and `default_model=claude-sonnet-4-6` | VERIFIED | File present; `jq -r '.models\|length'` = 3; `jq -r '.default_model'` = `claude-sonnet-4-6`; all three model names confirmed |
| 2 | `lib/exact-count.mjs` uses stable `client.messages.countTokens` (not `client.beta`), handles MODULE_NOT_FOUND and missing API key with advisory to stderr + exit 1 | VERIFIED | grep count=1 stable namespace, count=0 beta; `ANTHROPIC_API_KEY="" node lib/exact-count.mjs . 2>&1` prints advisory and exits 1 |
| 3 | `conjure audit --cost .` and `conjure audit --cost --exact .` parse flags without crashing; `CONJURE_COST` and `CONJURE_EXACT` are exported to `audit-setup.sh` | VERIFIED | `cmd_audit()` has while/case loop; both env vars appear in the bash invocation at lines 125-126 of `cli/conjure` |
| 4 | `conjure audit .` (no `--cost`) still exits rc ≤ 2 and produces no cost section | VERIFIED | `bash scripts/audit-setup.sh . \| grep -c "Cost Estimate"` = 0; cost section gated by `[ "${CONJURE_COST:-0}" = "1" ]` |
| 5 | `conjure audit --cost <target>` outputs `── Cost Estimate ──` section after the PASS/WARN/FAIL separator | VERIFIED | `CONJURE_COST=1 bash scripts/audit-setup.sh . 2>&1` outputs header; confirmed by live run and test suite assertion |
| 6 | Label line reads `Estimate: $X.XX ±20% (chars/4 heuristic · prices: 2026-05 · model: claude-sonnet-4-6)` | VERIFIED | Live output: `Estimate: $0.00 ±20% (chars/4 heuristic · prices: 2026-05 · model: claude-sonnet-4-6)`; test `grep -qE "Estimate: \$[0-9]+\.[0-9]{2} ±20%"` passes |
| 7 | Per-file breakdown table with columns File / Chars / ~Tokens / Est.Cost, sorted by cost descending, with TOTAL row | VERIFIED | `scripts/audit-setup.sh` lines 188-193 implement header, sort, and TOTAL row; `COST_TMP` mktemp pattern confirmed |
| 8 | `--exact` with no API key prints advisory `[--exact] ANTHROPIC_API_KEY not set — falling back to chars/4 heuristic.` and continues to exit ≤ 2 | VERIFIED | Live: `CONJURE_COST=1 CONJURE_EXACT=1 ANTHROPIC_API_KEY="" bash scripts/audit-setup.sh .` prints advisory; test `--exact fallback advisory present when API key absent` PASSES |
| 9 | Default cost path is fully offline; no curl/fetch/http in non-exact code path | VERIFIED | `grep -v '^#' scripts/audit-setup.sh \| grep -cE "curl\|fetch\|http[s]?:"` = 0; test assertion passes |
| 10 | `bash tests/run.sh` exits 0 with all cost estimator assertions passing | VERIFIED | Live run: PASS: 185, FAIL: 0; 8 cost-specific assertions all show checkmark |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/prices.json` | Baked price table with models, pricing_date, input_per_mtok, band_pct, default_model | VERIFIED | 29-line file; valid JSON; all required fields present; 2026-05 pricing |
| `lib/exact-count.mjs` | Opt-in Anthropic SDK token counting wrapper | VERIFIED | 63 lines; shebang present; `node:` prefix on 3 stdlib imports; stable namespace; dual error handling |
| `cli/conjure` | `cmd_audit()` with --cost / --exact flag parsing | VERIFIED | while/case loop confirmed at lines 113-127; both flags map to env vars; identical pattern to `cmd_init` |
| `scripts/audit-setup.sh` | Cost section guarded by CONJURE_COST=1 with CONJURE_HOME self-derivation, jq-based prices.json read, per-file breakdown table, exact-count.mjs integration | VERIFIED | Lines 138-196; guard at line 138; self-derivation at line 139; jq reads at lines 145-148; mktemp table at lines 167-184; label line at 194 |
| `tests/run.sh` | Cost estimator test section (COST-01, COST-02, COST-03) | VERIFIED | Lines 372-439; 8 assertions; `find templates .claude-plugin lib` scope includes lib/ for prices.json JSON validation |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `cli/conjure cmd_audit` | `scripts/audit-setup.sh` | `CONJURE_HOME="$CONJURE_HOME" CONJURE_COST="$do_cost" CONJURE_EXACT="$do_exact" bash "$CONJURE_HOME/scripts/audit-setup.sh"` | WIRED | Lines 125-126 of cli/conjure; env-var prefix pattern matches plan spec |
| `scripts/audit-setup.sh cost section` | `lib/prices.json` | `PRICE_FILE="$CONJURE_HOME/lib/prices.json"` then `jq -r` reads | WIRED | Lines 140-148 of audit-setup.sh; CONJURE_HOME self-derivation guards line 139 |
| `scripts/audit-setup.sh cost section` | `lib/exact-count.mjs` | `node "$CONJURE_HOME/lib/exact-count.mjs" "$TARGET"` when `CONJURE_EXACT=1` and API key present | WIRED | Lines 155-163 of audit-setup.sh; exit-code check at line 157; fallback on non-zero |
| `tests/run.sh cost section` | `scripts/audit-setup.sh` | `CONJURE_COST=1 bash "$CONJURE_HOME/scripts/audit-setup.sh" "$SANDBOX_DIR"` | WIRED | Line 378 of tests/run.sh; python-fastapi sandbox fixture used |
| `tests/run.sh JSON loop` | `lib/prices.json` | `find templates .claude-plugin lib -name '*.json'` | WIRED | Line 42 of tests/run.sh; lib/ scope confirmed |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| prices.json valid JSON with correct default_model | `jq empty lib/prices.json && jq -r '.default_model' lib/prices.json` | `claude-sonnet-4-6`, exit 0 | PASS |
| prices.json has 3 models | `jq -r '.models \| length' lib/prices.json` | `3` | PASS |
| exact-count.mjs exits non-zero with advisory when API key empty | `ANTHROPIC_API_KEY="" node lib/exact-count.mjs . 2>&1` | Advisory printed, exit 1 | PASS |
| audit-setup.sh cost section header appears | `CONJURE_COST=1 bash scripts/audit-setup.sh . 2>&1 \| grep "── Cost Estimate ──"` | Header line found | PASS |
| Label format with ±20% band and model name | `CONJURE_COST=1 bash scripts/audit-setup.sh . 2>&1 \| grep "Estimate:"` | `Estimate: $0.00 ±20% (chars/4 heuristic · prices: 2026-05 · model: claude-sonnet-4-6)` | PASS |
| Cost section absent without --cost | `bash scripts/audit-setup.sh . 2>&1 \| grep -c "Cost Estimate"` | `0` | PASS |
| --exact fallback advisory fires | `CONJURE_COST=1 CONJURE_EXACT=1 ANTHROPIC_API_KEY="" bash scripts/audit-setup.sh . 2>&1 \| grep "ANTHROPIC_API_KEY not set"` | Advisory line found | PASS |
| No network calls in default path | `grep -v '^#' scripts/audit-setup.sh \| grep -cE "curl\|fetch\|http[s]?:"` | `0` | PASS |
| Full test suite green | `bash tests/run.sh` | PASS: 185, FAIL: 0 | PASS |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `cli/conjure` | 171 | `# --apply: interactive merge (placeholder; production version uses diff tool)` | Info | `cmd_update --apply` — pre-existing stub from earlier phase, outside Phase 6 scope |

No TBD/FIXME/XXX markers found in any Phase 6 modified files. The placeholder comment at cli/conjure:171 is inside `cmd_update`, which is outside the Phase 6 change boundary.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| COST-01 | `conjure audit --cost` estimates per-session token cost using chars/4 heuristic and dated price table | SATISFIED | Cost section in audit-setup.sh lines 138-196; label line with chars/4 attribution; prices.json with 2026-05 dates; test assertions passing |
| COST-02 | Output labeled as estimate with ±band, names model and pricing date | SATISFIED | Label format: `Estimate: $X.XX ±20% (chars/4 heuristic · prices: 2026-05 · model: claude-sonnet-4-6)`; band_pct=20 from prices.json |
| COST-03 | Default cost path fully offline; `--exact` flag may call countTokens API | SATISFIED | Zero network calls in default path (grep confirmed); `--exact` gates node invocation; advisory fires on missing API key; fallback to heuristic preserves offline behavior |

### Human Verification Required

None. All phase-6 behaviors are verifiable programmatically. The cost estimate value ($0.00 when run against the conjure repo itself, which has no `.claude/` in the project root) is expected given the target — the test suite correctly runs against the `python-fastapi` fixture which has a `.claude/` directory, and the label format is fully verified there.

---

_Verified: 2026-05-25_
_Verifier: Claude (gsd-verifier)_
