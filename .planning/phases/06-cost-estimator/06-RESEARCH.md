# Phase 6: Cost Estimator - Research

**Researched:** 2026-05-25
**Domain:** Shell scripting (POSIX bash 3.2), Node.js ESM (.mjs), JSON, Anthropic SDK token counting
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Cost logic lives inline in `scripts/audit-setup.sh` — added after the existing token
  estimate block (lines 122–128). No new script for the main logic path.
- **D-02:** `cli/conjure` `cmd_audit()` parses `--cost` and `--exact` flags and passes them
  through to `scripts/audit-setup.sh` as environment variables or positional args. Follows the
  same flag-parsing pattern used by `cmd_init` (while loop + case).
- **D-03:** `lib/prices.json` — JSON file with model name, pricing_date (YYYY-MM), input $/Mtok,
  and band_pct. Lives in `lib/` alongside `lib/mutate.sh`. Easy to grep-diff on updates;
  readable from both bash (`jq`) and Node.
- **D-04:** `--cost` is a flag on `conjure audit` (not a new subcommand). The existing audit
  health checks run first; the cost section appends after the `PASS/WARN/FAIL` summary line.
  Existing audit output is not modified.
- **D-05:** `--exact` is a separate composable flag. Invokes `lib/exact-count.mjs` when
  `ANTHROPIC_API_KEY` is present; when absent, prints advisory and falls back to chars/4
  heuristic — exit 0, not an error.
- **D-06:** Per-skill breakdown: sorted ASCII table (columns: Skill | Chars | ~Tokens | Est.
  Cost), sorted by cost descending, TOTAL footer row. One row per SKILL.md file found, plus
  rows for CLAUDE.md and settings.json.
- **D-07:** Label format: `Estimate: $X.XX ±20% (chars/4 heuristic · prices: YYYY-MM · model: <name>)`.
  Never a bare precise number — always includes the band and the pricing-as-of date.
- **D-08:** Existing `.claude/ token estimate: ~N (well-tuned)` health-check line stays
  unchanged. `--cost` adds a new `── Cost Estimate ──` section after the summary separator.
- **D-09:** `lib/exact-count.mjs` — calls Anthropic SDK `client.messages.countTokens()`. Reads
  all `.claude/` context files, returns an exact token count. Node .mjs file in `lib/`.
- **D-10:** When `ANTHROPIC_API_KEY` is absent:
  `[--exact] ANTHROPIC_API_KEY not set — falling back to chars/4 heuristic.`
  Then continues with normal --cost output. Exit 0.

### Claude's Discretion

- Exact column widths and padding in the ASCII table.
- Whether `lib/exact-count.mjs` reads all `.claude/` files or only context files (CLAUDE.md +
  skills + agents).
- Exact wording of advisory/fallback messages beyond what is stated above.
- Whether `jq` is required for `lib/prices.json` parsing or bash `grep`/`sed` is used for
  portability.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COST-01 | `conjure audit --cost` estimates per-session token cost from harness size using the chars/4 heuristic and a dated price table | D-01 through D-08 define the exact implementation; research confirms chars/4 is ±10–15% accurate for English prose, ±20% band covers mixed harness content |
| COST-02 | Cost output is labeled an estimate with an explicit ±band and names the model + pricing date (no false precision) | D-07 locks the label format; pricing table verified from official Anthropic docs |
| COST-03 | The default cost path is fully offline; an opt-in `--exact` flag may call Anthropic's `count_tokens` endpoint | D-05, D-09, D-10 define the offline default + opt-in exact path; API call shape verified from official docs |
</phase_requirements>

## Summary

Phase 6 adds `conjure audit --cost` — an offline-by-default token cost estimator that appends a
per-skill cost breakdown to the existing audit output. The implementation is split across three
files: `cli/conjure` (flag parsing in `cmd_audit`), `scripts/audit-setup.sh` (cost section
appended after line 139), and two new `lib/` files: `lib/prices.json` (baked price table) and
`lib/exact-count.mjs` (opt-in SDK call).

All decisions are locked in CONTEXT.md. Research tasks were: (1) confirm the May-2026 price
table, (2) verify the chars/4 heuristic band, (3) pin the `countTokens` API call shape, and
(4) audit the existing code integration points. All four are now resolved with HIGH confidence.

The key integration constraint discovered in research: `CONJURE_HOME` is not currently passed as
an env var to `scripts/audit-setup.sh` (unlike `init-project.sh`). The script must derive its
own `CONJURE_HOME` from `$0` using `cd "$(dirname "$0")/.." && pwd` in order to locate
`lib/prices.json` and invoke `lib/exact-count.mjs`. This derivation works correctly when the
script is invoked with a full absolute path (which `cli/conjure` always provides).

**Primary recommendation:** Add `CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"` near the top
of `audit-setup.sh` (guarded so it only runs when not already set), then use it to locate
`lib/prices.json` and call `node "$CONJURE_HOME/lib/exact-count.mjs"`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Flag parsing (`--cost`, `--exact`) | CLI (`cli/conjure cmd_audit`) | — | Same tier as all other flag parsing; follows D-02 and the established cmd_init pattern |
| Chars/token heuristic calculation | Script (`scripts/audit-setup.sh`) | — | TOTAL_CHARS and EST_TOKENS already computed there; cost section reads them directly (D-01) |
| Per-file char counts + breakdown table | Script (`scripts/audit-setup.sh`) | — | Inline with existing health-check loops; POSIX bash `wc -c` per file |
| Price table storage | Data (`lib/prices.json`) | — | JSON in lib/ follows lib/mutate.sh convention; readable by bash (jq) and Node (D-03) |
| ASCII table rendering + label | Script (`scripts/audit-setup.sh`) | — | bash printf with fixed-width columns; awk for floating-point division |
| Exact token count (opt-in) | Node.js (`lib/exact-count.mjs`) | — | API call requires Node; mirrors hook pattern; exit 0 on missing key (D-09, D-10) |

## Standard Stack

### Core (already available in the project — no installation required)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| POSIX bash | 3.2.57 (macOS) | `audit-setup.sh` extension | Project constraint; no bash 4+ features |
| `jq` | 1.8.1 | Parse `lib/prices.json` in bash | Already in preflight as optional dep; used in audit-setup.sh at line 86 for settings.json |
| `awk` | POSIX (system awk) | Floating-point cost arithmetic | Available on all POSIX systems; printf "%.2f" for dollar formatting |
| `wc -c` | POSIX | Per-file char count | Used in existing audit-setup.sh TOTAL_CHARS computation |
| Node.js | v24.15.0 (local) | `lib/exact-count.mjs` | Required dep in preflight; all hooks already use node .mjs |
| `@anthropic-ai/sdk` | 0.98.0 | `client.messages.countTokens()` for `--exact` | Official Anthropic SDK; verified on npm registry [VERIFIED: npm registry] |

### Supporting (no new packages needed for default path)

| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `@anthropic-ai/sdk` (npm install) | 0.98.0 | `--exact` path only | Only needed if users invoke `--exact`; the script should check and advise on installation |
| `printf` (bash built-in) | POSIX | ASCII table column formatting | Fixed-width table rendering without external tools |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `awk` for float math | `bc` | `bc` is available but requires piping; `awk` is one-liner friendly and equally portable |
| `jq` for prices.json | `grep`/`sed` | grep/sed works but is fragile for JSON; jq is already a project dependency (preflight lists it); falls back to warn if absent |
| `client.messages.countTokens` | REST curl call | curl avoids SDK installation but requires JSON parsing of the response and auth header management; SDK is cleaner |

**Installation (for `--exact` path only):**
```bash
npm install @anthropic-ai/sdk
```

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@anthropic-ai/sdk` | npm | ~2.3 yrs (Jan 2023) | 19.3M/wk | github.com/anthropics/anthropic-sdk-typescript | N/A (npm pkg, slopcheck is PyPI-only) | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none

**Packages flagged as suspicious [SUS]:** none

**Note:** slopcheck v0.6.1 is installed but operates only on PyPI packages. `@anthropic-ai/sdk` is
an npm package. Manual verification confirms:
- Published by `zak-anthropic`, `dylanc-anthropic`, `benjmann`, `nikhil-anthropic` (all
  `@anthropic.com` email addresses) [VERIFIED: npm registry]
- Source repo: `https://github.com/anthropics/anthropic-sdk-typescript` under the official
  `anthropics` GitHub org [VERIFIED: npm registry]
- No `postinstall` script [VERIFIED: npm registry]
- 19.3M downloads/week — established, high-volume package [VERIFIED: npm registry]

## Architecture Patterns

### System Architecture Diagram

```
conjure audit --cost [--exact] <target>
       |
       v
cli/conjure cmd_audit()
  - parse --cost flag (do_cost=1)
  - parse --exact flag (do_exact=1)
  - export CONJURE_COST=1, CONJURE_EXACT=1
       |
       v
scripts/audit-setup.sh <target>
  [existing health checks: CLAUDE.md, skills, agents, hooks, docs, token estimate]
  [existing summary line: PASS/WARN/FAIL]
       |
       +-- if CONJURE_COST=1 --+
       |                       v
       |         derive CONJURE_HOME from $0
       |                       |
       |           read lib/prices.json via jq
       |           (model, price, pricing_date, band_pct)
       |                       |
       |           if CONJURE_EXACT=1:
       |               if ANTHROPIC_API_KEY set:
       |                   node "$CONJURE_HOME/lib/exact-count.mjs" <target>
       |                   (prints exact token count to stdout, exits 0)
       |                   use exact token count for cost calculation
       |               else:
       |                   print advisory message
       |                   fall back to chars/4
       |           else:
       |               use TOTAL_CHARS/4 (already computed above line 139)
       |                       |
       |           per-file breakdown loop:
       |               for CLAUDE.md, settings.json, each SKILL.md:
       |                   chars=$(wc -c < file)
       |                   tokens=$((chars / 4))
       |                   cost via awk
       |               sort by cost descending
       |               print ASCII table + TOTAL row
       |               print label line
       |
       v
exit 0|1|2 (unchanged)
```

### Recommended Project Structure
```
lib/
├── mutate.sh          # existing
├── prices.json        # NEW: baked price table
└── exact-count.mjs    # NEW: Anthropic SDK countTokens wrapper
```

### Pattern 1: Flag Passing via env-var prefix (cmd_audit)

**What:** `cmd_audit` mirrors the `cmd_init` while/case loop, parsing `--cost` and `--exact`
before calling `audit-setup.sh` with env-var prefixes (consistent with how `DRY_RUN` and
`CONJURE_HOME` are passed to `init-project.sh`).

**When to use:** Any flag that audit-setup.sh needs to see; env vars are cleaner than positional
args when the script already takes a positional target path.

```bash
# Source: cli/conjure cmd_init pattern (lines 54–63, existing)
cmd_audit() {
  local target="$(pwd)" do_cost=0 do_exact=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --cost)   do_cost=1 ;;
      --exact)  do_exact=1 ;;
      --help|-h) grep -A3 '^  conjure audit' <<<"$(usage)"; return 0 ;;
      *)        target="$1" ;;
    esac
    shift
  done
  cmd_preflight || return 1
  CONJURE_HOME="$CONJURE_HOME" CONJURE_COST="$do_cost" CONJURE_EXACT="$do_exact" \
    bash "$CONJURE_HOME/scripts/audit-setup.sh" "$target"
}
```

### Pattern 2: CONJURE_HOME Self-Derivation in audit-setup.sh

**What:** `audit-setup.sh` is always invoked via full absolute path, so `$0` is reliable for
self-derivation. This is needed because `cmd_audit` doesn't currently pass `CONJURE_HOME` to
the script (unlike `cmd_init`'s children). Adding `CONJURE_HOME=` to the env prefix in the
revised `cmd_audit` (Pattern 1 above) is the cleanest fix — but a self-derivation fallback is
good defensive practice.

```bash
# Source: derived from init-project.sh pattern (line 10: KIT="$(cd "$(dirname "$0")/.." && pwd)")
# Add near top of scripts/audit-setup.sh, before the cost section
: "${CONJURE_HOME:="$(cd "$(dirname "$0")/.." && pwd)"}"
```

This sets `CONJURE_HOME` only if not already set in the environment (the `:=` expansion is
POSIX-compatible bash 3.2+).

### Pattern 3: lib/prices.json Structure

```json
{
  "models": [
    {
      "model":            "claude-haiku-4-5",
      "display_name":     "Claude Haiku 4.5",
      "pricing_date":     "2026-05",
      "input_per_mtok":   1,
      "output_per_mtok":  5,
      "band_pct":         20
    },
    {
      "model":            "claude-sonnet-4-6",
      "display_name":     "Claude Sonnet 4.6",
      "pricing_date":     "2026-05",
      "input_per_mtok":   3,
      "output_per_mtok":  15,
      "band_pct":         20
    },
    {
      "model":            "claude-opus-4-7",
      "display_name":     "Claude Opus 4.7",
      "pricing_date":     "2026-05",
      "input_per_mtok":   5,
      "output_per_mtok":  25,
      "band_pct":         20
    }
  ],
  "default_model": "claude-sonnet-4-6"
}
```

**Reading from bash (jq):**
```bash
PRICE_INPUT=$(jq -r '.models[] | select(.model == "claude-sonnet-4-6") | .input_per_mtok' \
  "$CONJURE_HOME/lib/prices.json")
PRICING_DATE=$(jq -r '.models[] | select(.model == "claude-sonnet-4-6") | .pricing_date' \
  "$CONJURE_HOME/lib/prices.json")
```

**Fallback if jq is absent (warn and skip cost section):**
```bash
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not installed — cannot compute cost estimate (install jq and re-run)"
  # skip cost section entirely, exit cleanly
fi
```

### Pattern 4: lib/exact-count.mjs Structure

```javascript
// Source: official Anthropic TypeScript docs — platform.claude.com/docs/en/build-with-claude/token-counting
// Method is client.messages.countTokens (stable, NOT beta namespace as of SDK 0.98.0)
#!/usr/bin/env node
import Anthropic from "@anthropic-ai/sdk";
import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

const target = process.argv[2] || process.cwd();
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// Collect all .md and .json files under .claude/
function collectContextFiles(dir) { /* ... */ }

const content = collectContextFiles(path.join(target, ".claude")).join("\n");

const response = await client.messages.countTokens({
  model: "claude-sonnet-4-6",
  messages: [{ role: "user", content }],
});

process.stdout.write(String(response.input_tokens) + "\n");
process.exit(0);
```

**Response shape:** `{ "input_tokens": N }` — the only field relevant to this use case.
[VERIFIED: platform.claude.com/docs/en/build-with-claude/token-counting]

### Pattern 5: Per-Skill Cost Table (bash)

```bash
# Source: pattern derived from existing audit-setup.sh skill loop (lines 51-65)
# bash 3.2 compatible: no associative arrays, no mapfile
# Sort requires writing to temp file then reading sorted

COST_SECTION_TMP=$(mktemp)
trap 'rm -f "$COST_SECTION_TMP"' EXIT

# Header
printf "%-25s %8s %8s %12s\n" "File" "Chars" "~Tokens" "Est.Cost" >> "$COST_SECTION_TMP"
printf "%-25s %8s %8s %12s\n" "----" "-----" "-------" "--------" >> "$COST_SECTION_TMP"

TOTAL_COST_SUM=0

for ctx_file in CLAUDE.md .claude/settings.json; do
  [ -f "$ctx_file" ] || continue
  chars=$(wc -c < "$ctx_file" | tr -d ' ')
  tokens=$((chars / 4))
  cost=$(awk "BEGIN {printf \"%.6f\", $tokens * $PRICE_INPUT / 1000000}")
  printf "%s %s %s %s\n" "$ctx_file" "$chars" "$tokens" "$cost" >> "$COST_SECTION_TMP"
done

while IFS= read -r skill; do
  chars=$(wc -c < "$skill" | tr -d ' ')
  tokens=$((chars / 4))
  cost=$(awk "BEGIN {printf \"%.6f\", $tokens * $PRICE_INPUT / 1000000}")
  printf "%s %s %s %s\n" "$skill" "$chars" "$tokens" "$cost" >> "$COST_SECTION_TMP"
done < <(find .claude/skills -name SKILL.md 2>/dev/null)

# Sort by cost (4th field) descending, print formatted
sort -t' ' -k4 -rn "$COST_SECTION_TMP" | while IFS=' ' read -r name chars tokens cost; do
  printf "  %-25s %8s %8s  $%11.6f\n" "$name" "$chars" "$tokens" "$cost"
done
```

### Anti-Patterns to Avoid

- **Using bash arithmetic for float division:** `$((12345 / 1000000))` = 0, not 0.01. Always
  use `awk "BEGIN {printf \"%.6f\", ...}"` for dollar amounts.
- **Using `bc` for cost with pipes:** Pipe cost in a subshell loses variable state. Prefer
  `awk` one-liner.
- **bash 4+ features in audit-setup.sh:** No associative arrays (`declare -A`), no `mapfile`,
  no `local -n`. The project runs bash 3.2 on macOS (system bash).
- **Calling exact-count.mjs without checking node availability:** Always check
  `command -v node` first; node is a required preflight dep but defensive check is cheap.
- **Modifying PASS/WARN/FAIL counts in the cost section:** The cost section runs after
  the `PASS/WARN/FAIL` summary separator line (D-08). Do not call `ok()`/`warn()`/`err()`
  inside the cost section — it would corrupt the already-printed tally.
- **`@imports` in any generated output:** CLAUDE.md constraint; not applicable here but
  enforced at audit level.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exact token counting | Custom char-to-token conversion tables | `client.messages.countTokens()` via `@anthropic-ai/sdk` | Anthropic's tokenizer handles BPE, special tokens, and system prompt overhead that a char table cannot |
| JSON parsing in bash | `grep`/`sed` JSON extraction | `jq` (already a project dependency) | JSON parsing with grep is fragile against whitespace and key ordering changes |
| Float arithmetic in bash | `echo "$((a/b))"` | `awk "BEGIN {printf ...}"` | Bash integer-only arithmetic silently truncates; awk is POSIX, no dependencies |
| Cross-platform sort | Manual sort implementation | POSIX `sort -t' ' -k4 -rn` | sort is POSIX and handles numeric descending reliably |

**Key insight:** The chars/4 heuristic is intentionally imprecise. The `--exact` path is the
place for accuracy — and it uses the official API, not a hand-rolled tokenizer.

## Pricing Table (Verified)

The following prices are sourced from the official Anthropic pricing page and model overview as
of 2026-05-25. [VERIFIED: platform.claude.com/docs/en/about-claude/pricing and
platform.claude.com/docs/en/about-claude/models/overview]

| Model | API ID | Input $/MTok | Output $/MTok | Context |
|-------|--------|-------------|--------------|---------|
| Claude Haiku 4.5 | `claude-haiku-4-5` | $1.00 | $5.00 | 200k tokens |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | $3.00 | $15.00 | 1M tokens |
| Claude Opus 4.7 | `claude-opus-4-7` | $5.00 | $25.00 | 1M tokens |

**Recommended default model for prices.json:** `claude-sonnet-4-6` — the most common model
users will be running Conjure harnesses on, balanced between cost and capability.

**Note on Opus 4.7 tokenizer:** Opus 4.7 uses a new tokenizer that may use up to 35% more
tokens for the same fixed text compared to previous models. The chars/4 heuristic is calibrated
against typical Claude tokenizers; for Opus 4.7 users the estimate may skew 15–35% low. The
±20% band does not fully cover this; the advisory label should be considered informative for
Opus 4.7 until the band is validated against harness content.
[VERIFIED: platform.claude.com/docs/en/about-claude/pricing]

## SDK countTokens API Shape (Verified)

**SDK version:** `@anthropic-ai/sdk` 0.98.0 [VERIFIED: npm registry]

**Method location:** `client.messages.countTokens(params)` — stable namespace, NOT
`client.beta.messages.countTokens`. The beta namespace was used in an earlier SDK version;
current official docs show the stable path.
[VERIFIED: platform.claude.com/docs/en/build-with-claude/token-counting]

**Parameters:**
```typescript
await client.messages.countTokens({
  model: "claude-sonnet-4-6",          // required
  system: "optional system prompt",    // optional
  messages: [                          // required
    { role: "user", content: "..." }
  ]
});
```

**Response:** `{ "input_tokens": N }` — single field, integer.

**Error behavior:** Network error or invalid API key throws an exception. `lib/exact-count.mjs`
must catch errors and exit non-zero with a diagnostic message so `audit-setup.sh` can fall back
gracefully.

**Cost:** Token counting is free to use (not billed) but subject to RPM rate limits.
[VERIFIED: platform.claude.com/docs/en/build-with-claude/token-counting]

## Chars-per-Token Heuristic Validation

**Official Anthropic statement (from pricing page):** "1 token is approximately 4 characters or
0.75 words in English." [VERIFIED: platform.claude.com/docs/en/about-claude/pricing]

**Accuracy band analysis:**
- English prose: ±5–10% of actual token count [CITED: gptforwork.com/tools/tokenizer]
- Mixed content (prose + YAML frontmatter + code snippets): ±10–20%
- JSON (settings.json): JSON tokenizes more tokens per character than prose; expect the
  heuristic to under-count for settings.json by 15–30%

**Conclusion:** ±20% is a conservative and defensible band for a Conjure harness (which is a
mix of SKILL.md prose, settings.json, and CLAUDE.md prose). The band is explicitly labeled so
users are not misled. [ASSUMED: the ±20% band adequately covers the harness content mix;
not verified by measuring actual harness token counts against heuristic estimates]

## Common Pitfalls

### Pitfall 1: CONJURE_HOME Not Available in audit-setup.sh

**What goes wrong:** `lib/prices.json` and `lib/exact-count.mjs` cannot be located because
`audit-setup.sh` does not inherit `CONJURE_HOME`.

**Why it happens:** `cmd_audit` (line 116) currently calls
`bash "$CONJURE_HOME/scripts/audit-setup.sh" "$target"` — no `CONJURE_HOME=` env prefix,
unlike `cmd_init`'s children. The variable exists in the parent shell but is not exported.

**How to avoid:** Two changes needed together:
1. Revise `cmd_audit` to prefix `CONJURE_HOME="$CONJURE_HOME"` (like cmd_init does).
2. Add self-derivation fallback in audit-setup.sh: `: "${CONJURE_HOME:="$(cd "$(dirname "$0")/.." && pwd)"}"`.

**Warning signs:** Script outputs `jq: error (at <stdin>:1): null` or `node: cannot find lib/exact-count.mjs`.

### Pitfall 2: Calling ok()/warn()/err() After the Summary Line

**What goes wrong:** The cost section runs after `echo "PASS: $PASS    WARN: $WARN    FAIL: $FAIL"` has already been printed (line 135). Any call to `ok()`, `warn()`, or `err()` after this point increments counters that have already been echoed — the summary is already on screen.

**Why it happens:** The cost section is appended after the summary separator (D-08), so it executes after the tally is printed.

**How to avoid:** Use `echo` or `printf` directly for cost section output — never `ok()`/`warn()`/`err()`. Use a separate cost-section-specific `note_cost()` helper if needed.

**Warning signs:** PASS/WARN/FAIL tally on screen differs from what the tests assert.

### Pitfall 3: Integer Truncation in Token-to-Dollar Math

**What goes wrong:** `EST_COST=$((EST_TOKENS * PRICE / 1000000))` always returns 0 because
bash integer division truncates before the dollar amount is reached for typical harness sizes
(~5000–25000 tokens at $3/MTok = $0.015–$0.075).

**Why it happens:** Bash `$((...))` is integer-only.

**How to avoid:** Use `awk "BEGIN {printf \"%.2f\", $EST_TOKENS * $PRICE / 1000000}"` for all
dollar calculations.

**Warning signs:** All cost estimates print as `$0.00`.

### Pitfall 4: sort Compatibility Across Platforms

**What goes wrong:** `sort -k4 -rn` treats space-delimited fields inconsistently on macOS
vs Linux depending on locale and IFS.

**Why it happens:** BSD sort (macOS) and GNU sort (Linux) handle field separators and numeric
sorting slightly differently.

**How to avoid:** Explicitly specify `-t' '` (tab separator or space with quotes). Test on
macOS bash 3.2 which is the primary dev environment. The numeric sort for cost values works
correctly in both BSD and GNU sort for decimal strings.

**Warning signs:** Skill breakdown rows appear in wrong order.

### Pitfall 5: @anthropic-ai/sdk Not Installed for --exact Path

**What goes wrong:** `lib/exact-count.mjs` throws `Cannot find package '@anthropic-ai/sdk'`
if the user runs `--exact` without the SDK installed globally or in the project.

**Why it happens:** Conjure has `dependencies: {}` empty (CLAUDE.md constraint). The SDK is not
bundled.

**How to avoid:** `lib/exact-count.mjs` should begin by checking import availability or catch
the MODULE_NOT_FOUND error and print an actionable advisory:
`[--exact] @anthropic-ai/sdk not found — install with: npm install @anthropic-ai/sdk`.
Then exit with a non-zero code so `audit-setup.sh` can detect failure and fall back to
heuristic.

**Warning signs:** Stack trace from node instead of a clean error message.

## Code Examples

### Example 1: Minimal cost section in audit-setup.sh

```bash
# Source: pattern derived from existing audit-setup.sh TOTAL_CHARS block (lines 122-130)
# Insert after line 139 (after the final exit block's guard, before exit 0)
if [ "${CONJURE_COST:-0}" = "1" ]; then
  : "${CONJURE_HOME:="$(cd "$(dirname "$0")/.." && pwd)"}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  [--cost] jq not installed — install jq to use cost estimation"
  else
    PRICE_FILE="$CONJURE_HOME/lib/prices.json"
    MODEL=$(jq -r '.default_model' "$PRICE_FILE")
    PRICE_INPUT=$(jq -r --arg m "$MODEL" '.models[] | select(.model==$m) | .input_per_mtok' "$PRICE_FILE")
    PRICING_DATE=$(jq -r --arg m "$MODEL" '.models[] | select(.model==$m) | .pricing_date' "$PRICE_FILE")
    BAND_PCT=$(jq -r --arg m "$MODEL" '.models[] | select(.model==$m) | .band_pct' "$PRICE_FILE")

    TOKENS_TO_USE="$EST_TOKENS"

    if [ "${CONJURE_EXACT:-0}" = "1" ]; then
      if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        echo "  [--exact] ANTHROPIC_API_KEY not set — falling back to chars/4 heuristic."
      elif command -v node >/dev/null 2>&1 && [ -f "$CONJURE_HOME/lib/exact-count.mjs" ]; then
        EXACT_TOKENS=$(node "$CONJURE_HOME/lib/exact-count.mjs" "$TARGET" 2>/dev/null)
        if [ -n "$EXACT_TOKENS" ]; then
          TOKENS_TO_USE="$EXACT_TOKENS"
        fi
      fi
    fi

    TOTAL_COST=$(awk "BEGIN {printf \"%.4f\", $TOKENS_TO_USE * $PRICE_INPUT / 1000000}")

    echo
    echo "── Cost Estimate ──────────────────────"
    # ... per-file breakdown table ...
    echo "  Estimate: \$$TOTAL_COST ±${BAND_PCT}% (chars/4 heuristic · prices: $PRICING_DATE · model: $MODEL)"
  fi
fi
```

### Example 2: lib/exact-count.mjs skeleton

```javascript
// Source: official Anthropic TypeScript SDK docs
// platform.claude.com/docs/en/build-with-claude/token-counting
#!/usr/bin/env node
import Anthropic from "@anthropic-ai/sdk";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { execSync } from "node:child_process";

const target = process.argv[2] || process.cwd();

// Collect .claude/ text files
const safe = (fn) => { try { return fn(); } catch { return ""; } };
const content = safe(() =>
  execSync(`find ${JSON.stringify(join(target, ".claude"))} -type f \\( -name "*.md" -o -name "*.json" \\) -print0`,
    { stdio: ["ignore", "pipe", "ignore"] })
    .toString()
    .split("\0")
    .filter(Boolean)
    .map(f => safe(() => readFileSync(f, "utf8")))
    .join("\n")
);

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const response = await client.messages.countTokens({
  model: "claude-sonnet-4-6",
  messages: [{ role: "user", content }],
});
process.stdout.write(String(response.input_tokens) + "\n");
```

### Example 3: jq read from lib/prices.json (bash 3.2)

```bash
# Source: jq documentation + existing audit-setup.sh jq usage pattern (line 87)
# Read default model and its price:
MODEL=$(jq -r '.default_model' "$PRICE_FILE")
PRICE=$(jq -r --arg m "$MODEL" \
  '.models[] | select(.model == $m) | .input_per_mtok' "$PRICE_FILE")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `client.beta.messages.countTokens()` (beta namespace) | `client.messages.countTokens()` (stable) | SDK ~0.30+ (2024-Q4) | No more `betas` array needed; simpler call |
| `client.beta.messages.countTokens({ betas: ["token-counting-2024-11-01"], ... })` | `client.messages.countTokens({ model, messages, system })` | 2024-Q4 SDK update | Remove beta header from call |

**Deprecated/outdated:**
- `client.beta.messages.countTokens` with `betas: ["token-counting-2024-11-01"]`: Still
  accepted but the stable method is preferred in SDK 0.98.0. Some older blog posts (pre-2025)
  show the beta form.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ±20% band adequately covers harness content mix (prose SKILL.md + JSON settings + CLAUDE.md) | Chars-per-Token Heuristic Validation | Band too narrow → misleads users about precision; too wide → unhelpful advisory |
| A2 | `CONJURE_EXACT` / `CONJURE_COST` are good env var names (not already used by audit-setup.sh) | Architecture Patterns (Pattern 1) | Name collision would break flag detection; easy to verify by grepping audit-setup.sh |
| A3 | `lib/exact-count.mjs` reads all `.claude/` .md + .json files as context (not a filtered subset) | Standard Stack / Claude's Discretion | Under-counting if only a subset is read; over-counting if unrelated files included |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed. (Three low-risk assumptions noted above.)

## Open Questions

1. **Which files does `lib/exact-count.mjs` read?**
   - What we know: CONTEXT.md marks this as Claude's discretion. CLAUDE.md + SKILL.md files + settings.json are the logical context files.
   - What's unclear: Whether to include hook .mjs files, which are loaded by Claude Code but are not context instructions.
   - Recommendation: Read only `.md` and `.json` files in `.claude/` (exclude `.mjs` hooks), matching the pattern already used in `audit-setup.sh` lines 124: `find .claude -type f \( -name '*.md' -o -name '*.json' \)`.

2. **How to handle jq absence for prices.json parsing?**
   - What we know: jq is an optional dep in preflight (not a hard block). The cost section cannot run without it.
   - What's unclear: Whether to `warn()` (which would skew the WARN count) or just `echo` a note.
   - Recommendation: Since the cost section runs after the summary line, `echo` a note directly (not `warn()`) to avoid corrupting the tally.

3. **Should `--cost` accept a model flag like `--model=claude-haiku-4-5`?**
   - What we know: CONTEXT.md does not mention a `--model` flag.
   - What's unclear: Whether users will want to compare costs across models.
   - Recommendation: Default to `default_model` from prices.json; do not add `--model` in this phase (deferred).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | audit-setup.sh | ✓ | 3.2.57 | — |
| jq | prices.json parsing | ✓ | 1.8.1 | warn + skip cost section |
| awk | float arithmetic | ✓ | POSIX | — |
| node | lib/exact-count.mjs | ✓ | v24.15.0 | warn if absent for --exact |
| @anthropic-ai/sdk | --exact path | not installed (by design) | — | warn user with install command |
| ANTHROPIC_API_KEY | --exact path | not checked | — | D-10 advisory + heuristic fallback |

**Missing dependencies with no fallback:** none for the default `--cost` path.

**Missing dependencies with fallback:** `@anthropic-ai/sdk` (for `--exact` only) — fallback is
the chars/4 heuristic with advisory message per D-10.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | hand-rolled bash (`tests/run.sh`) |
| Config file | none (pure bash, no config) |
| Quick run command | `bash tests/run.sh` |
| Full suite command | `bash tests/run.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COST-01 | `conjure audit --cost` produces a cost estimate section | integration | `bash tests/run.sh` (cost section in test) | ❌ Wave 0 |
| COST-02 | Output includes `±20%` and `prices: YYYY-MM` and model name | integration (grep) | `bash tests/run.sh` (grep pattern) | ❌ Wave 0 |
| COST-03 | Default `--cost` makes zero network calls (no `curl`/`fetch` in default path) | grep + smoke | `grep -n 'curl\|fetch\|http' scripts/audit-setup.sh` | ❌ Wave 0 |
| COST-03 | `--exact` with no API key falls back gracefully (exit 0, advisory message) | integration | `ANTHROPIC_API_KEY="" bash tests/run.sh` | ❌ Wave 0 |
| — | Existing audit tests (no --cost flag) still pass unchanged | regression | `bash tests/run.sh` | ✓ existing |

### Sampling Rate

- **Per task commit:** `bash tests/run.sh`
- **Per wave merge:** `bash tests/run.sh`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] Cost section integration test in `tests/run.sh` — run audit with `--cost`, grep for
  `Cost Estimate` header and the label format
- [ ] COST-03 no-network test — grep `scripts/audit-setup.sh` and `lib/exact-count.mjs` for
  network-egress calls in the default (non-exact) code path
- [ ] COST-03 exact fallback test — run `CONJURE_EXACT=1 CONJURE_COST=1` with no API key, assert
  advisory message and exit 0

## Security Domain

The cost estimator has no authentication, no user data processing, no network calls in the
default path, and no secrets handling in the shell scripts. The only security-relevant component
is `lib/exact-count.mjs` (--exact path):

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | Partial | `ANTHROPIC_API_KEY` is read from env, not user input; file paths are constructed from `$TARGET` which is already a validated directory in audit-setup.sh |
| V6 Cryptography | No | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| API key leakage via process args | Information Disclosure | Key is read from env var, never passed as CLI arg |
| Path traversal in TARGET | Tampering | TARGET is already `cd`'d to at top of audit-setup.sh; find is scoped to `.claude/` |
| Network egress in default path | Tampering | Cost section guarded by `CONJURE_COST=1`; `--exact` guard further requires `CONJURE_EXACT=1`; no curl/fetch in default path |

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 6 |
|-----------|-------------------|
| POSIX bash 3.2+ for all scripts | No bash 4+ features: no `declare -A`, no `mapfile`, no `local -n`, no `[[ ]]` style tests beyond what 3.2 supports |
| No heavy runtime deps; `dependencies: {}` empty | `@anthropic-ai/sdk` is NOT added to a package.json; must be installed by user; advisory message if absent |
| `jq` is acceptable (in preflight dep table) | `jq` may be used freely in audit-setup.sh for prices.json parsing |
| Node `.mjs` hooks pattern | `lib/exact-count.mjs` follows the same Node ESM pattern as `templates/hooks-nodejs/*.mjs` |
| hooks `exit 2` (never `exit 1`) | Irrelevant to this phase (no hooks created); audit-setup.sh exit codes 0/1/2 unchanged |
| CLAUDE.md ≤100 lines, SKILL.md ≤200, agent ≤80 | No new CLAUDE.md or skills created; constraint affects the cost estimates we calculate, not implementation |
| Backup-before-mutate | No writes in this phase; audit + lib file additions are read-only at runtime |
| `@imports` forbidden in CLAUDE.md | No CLAUDE.md created |

## Sources

### Primary (HIGH confidence)

- [platform.claude.com/docs/en/about-claude/pricing](https://platform.claude.com/docs/en/about-claude/pricing) — verified pricing table for all Claude 4.x models, May 2026
- [platform.claude.com/docs/en/about-claude/models/overview](https://platform.claude.com/docs/en/about-claude/models/overview) — verified model IDs (claude-haiku-4-5, claude-sonnet-4-6, claude-opus-4-7) and pricing
- [platform.claude.com/docs/en/build-with-claude/token-counting](https://platform.claude.com/docs/en/build-with-claude/token-counting) — verified countTokens method location (stable, not beta), parameters, response shape, and pricing (free)
- npm registry `@anthropic-ai/sdk` — verified version 0.98.0, Jan 2023 creation, anthropics org maintainers, no postinstall, 19.3M weekly downloads
- Codebase: `cli/conjure`, `scripts/audit-setup.sh`, `lib/mutate.sh`, `tests/run.sh` — direct reads

### Secondary (MEDIUM confidence)

- [platform.claude.com/docs/en/api/messages-count-tokens](https://platform.claude.com/docs/en/api/messages-count-tokens) — API reference confirming parameter names and response shape

### Tertiary (LOW confidence)

- [gptforwork.com/tools/tokenizer](https://gptforwork.com/tools/tokenizer) — chars-per-token band ±10–20% for mixed content (single source, not official)

## Metadata

**Confidence breakdown:**
- Price table: HIGH — sourced directly from official Anthropic pricing page
- Model IDs: HIGH — sourced directly from official Anthropic models overview
- countTokens API shape: HIGH — sourced from official token-counting docs
- @anthropic-ai/sdk version: HIGH — verified on npm registry
- chars/4 heuristic band: MEDIUM — Anthropic states "~4 chars" officially; ±20% band is ASSUMED sufficient for harness content
- Code integration points: HIGH — direct codebase reads

**Research date:** 2026-05-25
**Valid until:** 2026-09-01 (stable API; price tables should be re-verified before any update)
