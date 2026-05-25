# Phase 13: Homebrew Tap - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 5 new/modified files
**Analogs found:** 4 / 5 (Formula/conjure.rb has no codebase analog — Ruby DSL first instance)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Formula/conjure.rb` | config (formula) | transform | none in codebase | no-analog (Ruby DSL first) |
| `cli/conjure` | utility (CLI dispatcher) | request-response | `cli/conjure` itself | self-extension (one-line edit) |
| `.github/workflows/release.yml` | config (CI/CD workflow) | event-driven | `.github/workflows/release.yml` itself | self-extension (append step) |
| `tests/run.sh` | test (regression suite) | batch | `tests/run.sh` lines 1077-1246 (OVLY block) | exact (same sandbox/trap/assert pattern) |
| `13-VALIDATION.md` | doc (validation contract) | n/a | `.planning/phases/12-org-overlay/12-VALIDATION.md` | exact (identical frontmatter + table schema) |

---

## Pattern Assignments

### `cli/conjure` (utility, request-response)

**Analog:** `cli/conjure` — self-extension, one-line change

**Exact line to change (line 24):**
```bash
# BEFORE (current line 24):
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

# AFTER (D-03):
CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
```

**Why this is safe — context lines 24-25 for verification:**
```bash
CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
CONJURE_VERSION="$(cat "$CONJURE_HOME/VERSION" 2>/dev/null || echo unknown)"
```
Line 25 already reads `$CONJURE_HOME/VERSION` — the conditional assignment makes an externally-set CONJURE_HOME win, which is exactly what the Homebrew wrapper needs. No other changes to `cli/conjure` are required.

---

### `.github/workflows/release.yml` (config, event-driven)

**Analog:** `.github/workflows/release.yml` — self-extension, append one step

**Existing step to append after (lines 36-42):**
```yaml
      - name: Create release
        uses: softprops/action-gh-release@v2
        with:
          body_path: release-notes.md
          draft: false
          prerelease: false
```

**New step to add immediately after the Create release step:**
```yaml
      - name: Bump Homebrew formula
        uses: mislav/bump-homebrew-formula-action@v3
        with:
          formula-name: conjure
          tap-repo: mohandoz/homebrew-conjure
          download-url: https://github.com/mohandoz/conjure/archive/refs/tags/${{ github.ref_name }}.tar.gz
        env:
          COMMITTER_TOKEN: ${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}
```

**Key constraints from existing workflow structure (lines 1-13):**
- Trigger is `push: tags: ['v*']` — bump action fires on every versioned tag, which is correct
- `permissions: contents: write` is already present on the job — no new permissions block needed
- `fetch-depth: 0` on the checkout step is already present — needed for tag resolution

---

### `tests/run.sh` (test, batch)

**Analog:** `tests/run.sh` lines 1077-1246 (OVLY block) — exact pattern match

**Block header pattern (lines 1077-1081):**
```bash
# ──────────────────────────────────────────────────────────────────────────────
# OVLY org-overlay tests (OVLY-01 through OVLY-05)
# ──────────────────────────────────────────────────────────────────────────────
echo
echo "▸ OVLY org-overlay tests (OVLY-01 through OVLY-05)"
```
Copy this header style verbatim for the BREW block, substituting OVLY with BREW.

**Static-grep test pattern (lines 1234-1243):**
```bash
# OVLY-05: no credential keywords in worker scripts (static grep)
if grep -qE 'password|credential|token' "$CONJURE_HOME/scripts/init-overlay.sh" 2>/dev/null; then
  fail "init-overlay.sh contains credential keyword (OVLY-05)"
else
  pass "init-overlay.sh contains no credential keywords (OVLY-05)"
fi
```
BREW-03 and BREW-04 use this same static-grep pattern — grep the formula for forbidden tokens (`branch`, `HEAD`) and grep the release YAML for the bump-action reference.

**Env-override unit test pattern (lines 108-113 — preflight section, adapted):**
```bash
if bash scripts/preflight.sh >/dev/null 2>&1; then
  pass "scripts/preflight.sh: exits 0 (all required deps present)"
else
  fail "scripts/preflight.sh: non-zero exit (required dep missing in test env?)"
fi
```
BREW-02 uses the same pattern: set `CONJURE_HOME=/tmp/fake`, write a fake VERSION, call `cli/conjure version`, assert it reads the fake file:
```bash
# BREW-02: CONJURE_HOME env var override
BREW_FAKE="$(mktemp -d)"
printf '9.8.7\n' > "$BREW_FAKE/VERSION"
BREW_VER_OUT="$(CONJURE_HOME="$BREW_FAKE" cli/conjure version 2>&1)"
if printf '%s\n' "$BREW_VER_OUT" | grep -q '9.8.7'; then
  pass "CONJURE_HOME env var overrides default resolution (BREW-02)"
else
  fail "CONJURE_HOME env var did NOT override default — got: $BREW_VER_OUT (BREW-02)"
fi
rm -rf "$BREW_FAKE"
```

**Sandbox trap lifecycle (lines 255-268 — fixture audit block):**
```bash
sandbox_setup "$fx"
trap 'rm -rf "$SANDBOX_DIR"' EXIT
# ... assertions ...
rm -rf "$SANDBOX_DIR"
trap - EXIT
```
BREW tests that create temp dirs must follow this pattern: `mktemp -d`, `trap 'rm -rf ...' EXIT`, assertions, explicit `rm -rf`, `trap - EXIT`. Never leave cleanup only to the EXIT trap without also removing explicitly.

**pass/fail assertion helpers (lines 14-16):**
```bash
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
```
These are already defined at the top of run.sh — do not redefine them in the BREW block.

**Placement:** The BREW block should be appended before the final summary block (lines 1248-1254). The summary block is:
```bash
# Summary
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "PASS: $PASS    FAIL: $FAIL"
echo "═══════════════════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
```

---

### `13-VALIDATION.md` (doc, n/a)

**Analog:** `.planning/phases/12-org-overlay/12-VALIDATION.md` — exact format

**Frontmatter block (lines 1-8):**
```yaml
---
phase: 12
slug: org-overlay
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-26
---
```
Copy verbatim, changing `phase: 12`, `slug: org-overlay` to `phase: 13`, `slug: homebrew-tap`.

**Test Infrastructure table (lines 17-23):**
```markdown
| Property | Value |
|----------|-------|
| **Framework** | Hand-rolled bash test runner |
| **Config file** | none |
| **Quick run command** | `bash tests/run.sh` |
| **Full suite command** | `bash tests/run.sh` |
| **Estimated runtime** | ~15 seconds |
```
Copy verbatim — same test framework applies.

**Per-Task Verification Map columns (line 39):**
```markdown
| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
```
Phase 12 uses this 9-column schema (no "Threat Ref" column). Phase 11 has a 10-column schema with "Threat Ref". Use the **Phase 12 schema** (9 columns) — it matches the BREW tasks which have no threat model entries.

**Wave 0 Requirements section (lines 59-64):**
```markdown
## Wave 0 Requirements

- [ ] OVLY test blocks in `tests/run.sh` — all 12 test assertions above
- [ ] `scripts/init-overlay.sh` — new worker script (created in Wave 1)
- [ ] `scripts/refresh-overlay.sh` — new worker script (created in Wave 1)

*No separate test infrastructure needed — all tests inline in `tests/run.sh` following established pattern.*
```
Adapt to: BREW test blocks in `tests/run.sh` (Wave 0 dependency items per BREW-01 through BREW-04).

**Manual-Only Verifications section (lines 68-73):**
```markdown
| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Private repo auth uses git credential store | OVLY-05 | Requires real private repo... | Run ... |
```
BREW-01 (actual `brew install`) and BREW-04 (live tap repo bump) are manual-only. Use this table to document them.

---

### `Formula/conjure.rb` (config/formula, transform)

**No codebase analog** — this is the first Ruby file in the project. The formula follows standard Homebrew DSL conventions. The planner must use the CONTEXT.md `<specifics>` section and Homebrew documentation patterns.

**Key structural pattern to follow (from CONTEXT.md D-06 and D-04):**
```ruby
class Conjure < Formula
  desc "Missing init kit for Claude Code"
  homepage "https://github.com/mohandoz/conjure"
  url "https://github.com/mohandoz/conjure/archive/refs/tags/vVERSION.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  def install
    # Install all runtime dirs under share/conjure
    (share/"conjure").install "cli", "scripts", "profiles", "compliance",
                             "migrations", "templates", "lib", "VERSION"

    # Wrapper script sets CONJURE_HOME before exec-ing the real dispatcher
    (bin/"conjure").write <<~EOS
      #!/bin/bash
      export CONJURE_HOME="#{share}/conjure"
      exec "#{share}/conjure/cli/conjure" "$@"
    EOS
  end

  test do
    system "#{bin}/conjure", "version"
  end
end
```

**Constraint (BREW-03):** Formula URL must reference a tagged tarball, never a branch or HEAD ref. The static grep test in BREW-03 verifies absence of `branch` and `HEAD` tokens in the formula.

---

## Shared Patterns

### CONJURE_HOME Env-var Override
**Source:** `cli/conjure` line 24 (after D-03 edit)
**Apply to:** BREW-02 test in `tests/run.sh` (the test validates this exact behavior)
```bash
CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
```

### Temp-dir Lifecycle (mktemp + trap)
**Source:** `tests/run.sh` lines 255-268, 338-348, 619-651 (repeated pattern throughout)
**Apply to:** All BREW test blocks that create temp dirs
```bash
BREW_DIR="$(mktemp -d)"
trap 'rm -rf "$BREW_DIR"' EXIT
# ... assertions ...
rm -rf "$BREW_DIR"
trap - EXIT
```
Rule: always pair `mktemp -d` with an immediate `trap ... EXIT`, then clean up explicitly and call `trap - EXIT` after the block. Never accumulate multiple EXIT traps.

### Static Grep Test Pattern
**Source:** `tests/run.sh` lines 165-183 (template lint), 1234-1243 (OVLY-05)
**Apply to:** BREW-03 (formula HEAD/branch check), BREW-04 (workflow bump-action check)
```bash
if grep -qE 'FORBIDDEN_PATTERN' "$TARGET_FILE" 2>/dev/null; then
  fail "message describing what was found (TEST-ID)"
else
  pass "message describing clean state (TEST-ID)"
fi
```

### GitHub Actions Step Structure
**Source:** `.github/workflows/release.yml` lines 13-42; `.github/workflows/ci.yml` lines 9-65
**Apply to:** bump-homebrew-formula-action step in release.yml
- Steps use `name:` as the first key
- Action references use `uses:` at same indent as `name:`
- `with:` block indented under `uses:`
- `env:` block at same level as `with:` for secrets
- No `id:` needed unless a later step references this step's output

### Validation Doc Frontmatter
**Source:** `.planning/phases/12-org-overlay/12-VALIDATION.md` lines 1-8
**Apply to:** `13-VALIDATION.md`
All phase validation docs use the same 7-key YAML frontmatter. Status starts as `draft`, both boolean flags start `false`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Formula/conjure.rb` | config (formula) | transform | No Ruby files exist in the codebase; first Homebrew formula. Planner must use CONTEXT.md `<specifics>` and standard Homebrew DSL conventions. |

---

## Metadata

**Analog search scope:** `cli/`, `.github/workflows/`, `tests/`, `scripts/`, `.planning/phases/`
**Files scanned:** 7 (cli/conjure, release.yml, ci.yml, tests/run.sh, publish-plugin.sh, 12-VALIDATION.md, 11-VALIDATION.md)
**Pattern extraction date:** 2026-05-26
