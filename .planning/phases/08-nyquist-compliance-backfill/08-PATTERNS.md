# Phase 08: Nyquist Compliance Backfill — Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 6 (all new VALIDATION.md files)
**Analogs found:** 0 exact / 6 role-match (tests/run.sh sections)

---

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `.planning/phases/01-pre-flight-cross-platform-hooks/01-VALIDATION.md` | validation-doc | request-response | `tests/run.sh` lines 104–159 | role-match (preflight section) |
| `.planning/phases/02-dry-run-enforcement-chokepoint/02-VALIDATION.md` | validation-doc | request-response | `tests/run.sh` lines 186–221 | role-match (dry-run section) |
| `.planning/phases/04-regression-suite-dry-run-proof/04-VALIDATION.md` | validation-doc | batch | `tests/run.sh` lines 252–375 | role-match (fixture + snapshot + FM sections) |
| `.planning/phases/05-readme-demo/05-VALIDATION.md` | validation-doc | file-I/O | `tests/run.sh` lines 27 + 175–183 | role-match (smoke + template lint) |
| `.planning/phases/06-cost-estimator/06-VALIDATION.md` | validation-doc | request-response | `tests/run.sh` lines 378–444 | role-match (COST section) |
| `.planning/phases/07-skill-firing-telemetry/07-VALIDATION.md` | validation-doc | event-driven | `tests/run.sh` lines 448–603 | role-match (TLMY section) |

---

## Shared Pattern: Standalone Tmpdir Block

**Mandated by D-02 in CONTEXT.md. Apply to every verify block in every VALIDATION.md.**

Every `## Verify` code block must be independently copy-paste-runnable with its own
tmpdir setup and trap teardown. Do NOT share state across blocks.

**Pattern (inlined from D-02 and tests/run.sh lines 188–221):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"
# ... exercise the behavior ...
```

Cleanup idiom used in tests/run.sh (lines 218–221) for explicit mid-block teardown:
```bash
rm -rf "$TMPDIR_TARGET"
trap - EXIT
```

**Note:** The trap must be reset (`trap - EXIT`) before registering a new one in a
subsequent block, to avoid one trap overwriting another (observed issue in run.sh comment
at line 219: "sandbox_setup would overwrite this trap").

---

## Shared Pattern: CONJURE_HOME Resolution

**Source:** `tests/run.sh` lines 6–7
**Apply to:** Any verify block that invokes `cli/conjure` or `scripts/*.sh`

```bash
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
```

For standalone verify commands where the script location is unknown to the reader,
use an absolute resolution hint in the Expected output comment, or assume the reader
runs from the repo root and uses `CONJURE_HOME=$(pwd)`.

---

## Shared Pattern: Document Header

**Mandated by D-03 and D-04 in CONTEXT.md.**

Every VALIDATION.md starts with:
```markdown
<!-- Covers: TECH-02x | <test IDs from the phase> -->
# Phase N VALIDATION
```

Then one `## Verify <behavior>` section per testable claim, structured as:
```markdown
## Verify <behavior>

\`\`\`bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
# commands
\`\`\`

**Expected:** <grep-friendly partial pattern, not verbatim full output>
```

---

## Pattern Assignments

### `01-VALIDATION.md` — Pre-flight & Cross-Platform Hooks

**Requirement:** TECH-02a
**Phase requirements covered:** SAFE-03 (node .mjs hook wiring), SAFE-04 (preflight.sh)
**Analog section in tests/run.sh:** lines 104–183

**Test IDs to reference in header:** SAFE-03, SAFE-04

**Verify block 1 — preflight smoke (lines 109–113):**
```bash
bash scripts/preflight.sh
```
Expected pattern: `exits 0` (all required deps present in normal env)

**Verify block 2 — block on missing required dep (lines 117–128):**
```bash
STRIPPED_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r dir; do
  [ -x "$dir/node" ] || printf '%s\n' "$dir"
done | tr '\n' ':' | sed 's/:$//')"
PATH="$STRIPPED_PATH" bash scripts/preflight.sh
echo "exit: $?"
```
Expected pattern: `exit: [^0]` (non-zero exit when node absent)

**Verify block 3 — fix-it output has OS-aware package manager hint (lines 131–145):**
```bash
STRIPPED_PATH="..."   # same node-strip as above
OUTPUT="$(PATH="$STRIPPED_PATH" bash scripts/preflight.sh 2>&1 || true)"
printf '%s\n' "$OUTPUT" | grep -E "brew|apt|winget"
```
Expected pattern: `brew` (macOS) or `apt|winget` (Linux/Windows)

**Verify block 4 — settings.json.tmpl has node hook wiring, not bash (lines 162–183):**
```bash
grep -c 'node .claude/hooks/' templates/settings.json.tmpl
grep -c 'bash .claude/hooks/' templates/settings.json.tmpl
```
Expected pattern: node line count >= 1; bash line count = 0

**Verify block 5 — init-project.sh sources hooks-nodejs, no chmod on .mjs (lines 175–183):**
```bash
grep 'hooks-nodejs' scripts/init-project.sh
grep -v '^#' scripts/init-project.sh | grep -c 'chmod.*hooks'
```
Expected pattern: `hooks-nodejs` found; chmod count = 0

---

### `02-VALIDATION.md` — Dry-Run Enforcement Chokepoint

**Requirement:** TECH-02b
**Phase requirements covered:** SAFE-01 (no filesystem mutation on --dry-run), SAFE-02 (lib/mutate.sh chokepoint)
**Analog section in tests/run.sh:** lines 186–221

**Test IDs to reference in header:** SAFE-01, SAFE-02, D-04, D-05

**Verify block 1 — dry-run creates no filesystem artifacts (lines 196–202):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# Test project\n' > "$TMPDIR/CLAUDE.md"
CONJURE_HOME=$(pwd) cli/conjure init --dry-run "$TMPDIR" >/dev/null 2>&1 || true
[ -d "$TMPDIR/.claude" ] && echo "FAIL: .claude created" || echo "PASS: no .claude"
```
Expected pattern: `PASS: no .claude`

**Verify block 2 — [dry-run] prefix lines appear in output (lines 204–209):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# Test project\n' > "$TMPDIR/CLAUDE.md"
CONJURE_HOME=$(pwd) cli/conjure init --dry-run "$TMPDIR" 2>&1 | grep '\[dry-run\]' | head -3
```
Expected pattern: `[dry-run]` (one or more prefix lines present)

**Verify block 3 — mutation count in summary line > 0 (lines 210–215):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# Test project\n' > "$TMPDIR/CLAUDE.md"
CONJURE_HOME=$(pwd) cli/conjure init --dry-run "$TMPDIR" 2>&1 | grep -E '\[dry-run\] [1-9][0-9]* mutations skipped'
```
Expected pattern: `[dry-run] N mutations skipped` where N >= 1

**Verify block 4 — lib/mutate.sh functions exist and respect DRY_RUN (from lib/mutate.sh lines 21–75):**
```bash
source lib/mutate.sh
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
DRY_RUN=1 mutate_mkdir "$TMPDIR/would-not-exist"
[ -d "$TMPDIR/would-not-exist" ] && echo "FAIL: dir created" || echo "PASS: mkdir suppressed"
DRY_RUN=1 mutate_write "$TMPDIR/would-not-exist.txt" "content"
[ -f "$TMPDIR/would-not-exist.txt" ] && echo "FAIL: file written" || echo "PASS: write suppressed"
```
Expected pattern: `PASS: mkdir suppressed` and `PASS: write suppressed`

---

### `04-VALIDATION.md` — Regression Suite & Dry-Run Proof

**Requirement:** TECH-02c
**Phase requirements covered:** TEST-03 (golden-file EXPECT loop), TEST-05 (byte-identical snapshot), TEST-07 (failure modes)
**Analog section in tests/run.sh:** lines 252–375

**Test IDs to reference in header:** TEST-03, TEST-05, TEST-06, TEST-07

**Verify block 1 — sandboxed fixture audits exit 0 for all green fixtures (lines 252–268):**
```bash
CONJURE_HOME=$(pwd)
for fx in tests/fixtures/[^_]*/; do
  prof=$(basename "$fx")
  TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
  cp -r "$fx/." "$TMPDIR/"
  bash scripts/audit-setup.sh "$TMPDIR" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && echo "PASS: $prof" || echo "FAIL: $prof (rc=$rc)"
  rm -rf "$TMPDIR"; trap - EXIT
done
```
Expected pattern: `PASS:` for each named profile (python-fastapi, ts-next, etc.); no `FAIL:`

**Verify block 2 — _broken fixture audit exits non-zero (lines 273–291):**
```bash
CONJURE_HOME=$(pwd)
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cp -r tests/fixtures/_broken/. "$TMPDIR/"
bash scripts/audit-setup.sh "$TMPDIR" 2>&1
echo "exit: $?"
```
Expected pattern: `exit: [^0]` and at least one pattern from `tests/fixtures/_broken/EXPECT`

**Verify block 3 — dry-run leaves fixture trees byte-identical (lines 317–332):**
```bash
CONJURE_HOME=$(pwd)
ORIG=$(mktemp -d); SNAP=$(mktemp -d); trap 'rm -rf "$ORIG" "$SNAP"' EXIT
fx=tests/fixtures/python-fastapi
cp -r "$fx/." "$ORIG/"; cp -r "$fx/." "$SNAP/"
cli/conjure init --dry-run "$SNAP" >/dev/null 2>&1 || true
diff -r "$SNAP" "$ORIG" && echo "PASS: byte-identical" || echo "FAIL: diff found"
```
Expected pattern: `PASS: byte-identical`

**Verify block 4 — FM-1: audit detects CLAUDE.md size cap violation (lines 337–348):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# size-cap test\n' > "$TMPDIR/CLAUDE.md"
for i in $(seq 1 205); do printf '# filler %s\n' "$i" >> "$TMPDIR/CLAUDE.md"; done
bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep -i "HARD CAP exceeded"
```
Expected pattern: `HARD CAP exceeded`

---

### `05-VALIDATION.md` — README Demo

**Requirement:** TECH-02d
**Phase requirements covered:** DOCS-01 (demo.gif embedded in README; record-demo.sh)
**Analog section in tests/run.sh:** lines 27 (CLI smoke) + implied from phase plan

**Test IDs to reference in header:** DOCS-01

**Note:** Phase 5 is documentation-centric. The verifiable artifacts are:
1. `scripts/record-demo.sh` exists and is executable
2. `README.md` contains an embedded demo GIF reference
3. CLI `conjure version` exits 0 (smoke)

**Verify block 1 — scripts/record-demo.sh exists and is executable:**
```bash
[ -x scripts/record-demo.sh ] && echo "PASS: executable" || echo "FAIL: missing or not executable"
```
Expected pattern: `PASS: executable`

**Verify block 2 — README.md references demo.gif:**
```bash
grep -i 'demo\.gif\|demo\.cast\|asciinema' README.md
```
Expected pattern: filename match (demo.gif or similar)

**Verify block 3 — CLI smoke (mirrors tests/run.sh line 27):**
```bash
cli/conjure version
echo "exit: $?"
```
Expected pattern: version string output; `exit: 0`

---

### `06-VALIDATION.md` — Cost Estimator

**Requirement:** TECH-02e
**Phase requirements covered:** COST-01 (section present), COST-02 (label format), COST-03 (no network)
**Analog section in tests/run.sh:** lines 378–444

**Test IDs to reference in header:** COST-01, COST-02, COST-03

**Verify block 1 — cost section header present when CONJURE_COST=1 (lines 384–392):**
```bash
CONJURE_HOME=$(pwd)
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cp -r tests/fixtures/python-fastapi/. "$TMPDIR/"
CONJURE_COST=1 bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep '── Cost Estimate ──'
```
Expected pattern: `── Cost Estimate ──`

**Verify block 2 — cost label has ±20% band and pricing date (lines 395–411):**
```bash
CONJURE_HOME=$(pwd)
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cp -r tests/fixtures/python-fastapi/. "$TMPDIR/"
CONJURE_COST=1 bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep -E 'Estimate: \$[0-9]+\.[0-9]{2} ±20%'
CONJURE_COST=1 bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep 'prices:'
```
Expected pattern first grep: `Estimate: $X.XX ±20%`
Expected pattern second grep: `prices:` with a date string

**Verify block 3 — no network calls in audit-setup.sh (lines 423–428):**
```bash
grep -v '^#' scripts/audit-setup.sh | grep -cE 'curl|fetch|http[s]?:' || true
```
Expected pattern: `0` (zero network call patterns)

**Verify block 4 — --exact advisory when ANTHROPIC_API_KEY absent (lines 431–442):**
```bash
CONJURE_HOME=$(pwd)
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cp -r tests/fixtures/python-fastapi/. "$TMPDIR/"
CONJURE_COST=1 CONJURE_EXACT=1 ANTHROPIC_API_KEY="" bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep 'ANTHROPIC_API_KEY not set'
```
Expected pattern: `ANTHROPIC_API_KEY not set`

---

### `07-VALIDATION.md` — Skill-Firing Telemetry

**Requirement:** TECH-02f
**Phase requirements covered:** TLMY-01 (opt-in gate), TLMY-02 (JSONL write), TLMY-03 (no egress), TLMY-04 (retire-list), TLMY-05 (TELEMETRY.md)
**Analog section in tests/run.sh:** lines 448–603

**Test IDs to reference in header:** TLMY-01, TLMY-02, TLMY-03, TLMY-04, TLMY-05

**Verify block 1 — hook file exists (lines 451–455):**
```bash
[ -f templates/hooks-nodejs/skill-telemetry.mjs ] && echo "PASS: exists" || echo "FAIL: missing"
```
Expected pattern: `PASS: exists`

**Verify block 2 — no network egress patterns in hook (lines 458–467):**
```bash
grep -cE 'curl|fetch|http|socket|XMLHttpRequest|require\(.https.\)|require\(.http.\)|import.*https|import.*http|net\.Socket' \
  templates/hooks-nodejs/skill-telemetry.mjs || true
```
Expected pattern: `0` (zero egress patterns)

**Verify block 3 — hook exits 0 silently when CONJURE_TELEMETRY unset (lines 498–503):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '{}' | CONJURE_TELEMETRY="" node templates/hooks-nodejs/skill-telemetry.mjs >/dev/null 2>&1
echo "exit: $?"
[ -f "$TMPDIR/.claude/telemetry/skill-events.jsonl" ] && echo "FAIL: file written" || echo "PASS: no file"
```
Expected pattern: `exit: 0` and `PASS: no file`

**Verify block 4 — DO_NOT_TRACK=1 suppresses writes (lines 513–526):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
PAYLOAD='{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill_name":"test"},"session_id":"s1","cwd":"'"$TMPDIR"'"}'
printf '%s' "$PAYLOAD" | DO_NOT_TRACK=1 CONJURE_TELEMETRY=1 node templates/hooks-nodejs/skill-telemetry.mjs >/dev/null 2>&1
echo "exit: $?"
[ -f "$TMPDIR/.claude/telemetry/skill-events.jsonl" ] && echo "FAIL: file written" || echo "PASS: suppressed"
```
Expected pattern: `exit: 0` and `PASS: suppressed`

**Verify block 5 — hook writes JSONL with required fields when CONJURE_TELEMETRY=1 (lines 529–562):**
```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
PAYLOAD='{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill_name":"test-skill"},"session_id":"sess-001","cwd":"'"$TMPDIR"'"}'
printf '%s' "$PAYLOAD" | CONJURE_TELEMETRY=1 node templates/hooks-nodejs/skill-telemetry.mjs >/dev/null 2>&1
cat "$TMPDIR/.claude/telemetry/skill-events.jsonl"
```
Expected pattern: JSON line containing `skill_invoke`, `test-skill`, `session_id`, `project_cwd`

**Verify block 6 — retire-list section renders when CONJURE_RETIRE=1 (lines 589–601):**
```bash
CONJURE_HOME=$(pwd)
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cp -r tests/fixtures/python-fastapi/. "$TMPDIR/"
CONJURE_RETIRE=1 bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep '── Skill Retire-List ──'
```
Expected pattern: `── Skill Retire-List ──`

**Verify block 7 — TELEMETRY.md at repo root with required fields (lines 471–483):**
```bash
[ -f TELEMETRY.md ] && echo "PASS: exists" || echo "FAIL: missing"
grep -c 'session_id\|project_cwd\|DO_NOT_TRACK' TELEMETRY.md
```
Expected pattern: `PASS: exists` and grep count >= 3

---

## No Analog Found

There are no existing `VALIDATION.md` files anywhere in the codebase. Phase 03 was
listed as the only Nyquist-compliant phase, but its VALIDATION.md does not exist on
the current branch (deleted during v0.3.0 cleanup per git status). The only usable
analog is the section structure in `tests/run.sh`.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| All 6 VALIDATION.md files | validation-doc | — | No prior VALIDATION.md exists in codebase; tests/run.sh sections are the only analog |

---

## Metadata

**Analog search scope:** `.planning/phases/`, `tests/`, `lib/`
**Files scanned:** `tests/run.sh` (613 lines), `tests/lib/sandbox.sh` (48 lines), `lib/mutate.sh` (76 lines), `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/milestones/v0.3.0-ROADMAP.md`
**Pattern extraction date:** 2026-05-25
