# Phase 5: README Demo - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 4 (1 new script, 1 new binary artifact, 2 modified files)
**Analogs found:** 3 / 4 (demo.gif has no code analog — it is a binary artifact)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/record-demo.sh` | utility | batch (preflight → subprocess → file-I/O) | `scripts/regen-fixtures.sh` | exact (same role, same data flow) |
| `.github/assets/demo.gif` | binary artifact | file-I/O (write-once) | `.github/assets/logo.svg` | directory-convention only (no code pattern) |
| `README.md` | docs | static embed | `README.md` lines 63–76 (self) | self-modification — Quickstart section is the target |
| `.github/workflows/ci.yml` | config | CI assertion | `.github/workflows/ci.yml` lines 30–34 (self) | self-modification — `test` job step list is the target |

---

## Pattern Assignments

### `scripts/record-demo.sh` (utility, batch)

**Analog:** `scripts/regen-fixtures.sh`

**Shebang + header comment pattern** (`scripts/regen-fixtures.sh` lines 1–7):
```bash
#!/usr/bin/env bash
# scripts/regen-fixtures.sh — regenerate all (or one) committed test fixtures.
# Usage: bash scripts/regen-fixtures.sh [--profile <profile>] [--update-expect]
#   --profile <p>  Regenerate a single profile instead of all 9.
#   --update-expect  Write EXPECT files (alongside fixture content) without re-running conjure init.
# Profiles: ts-next java-spring rust-axum go-gin python-fastapi node-nest monorepo polyglot data-science
```

`record-demo.sh` should open with an identical style: one-line purpose comment, `Usage:`, `Requires:`, `Output:`.

**set -euo pipefail + CONJURE_HOME resolution** (`scripts/regen-fixtures.sh` lines 8–11):
```bash
set -euo pipefail

CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES_DIR="$CONJURE_HOME/tests/fixtures"
```

Copy verbatim — resolve `CONJURE_HOME` from `dirname "$0"` and set `ASSETS_DIR="$CONJURE_HOME/.github/assets"`.

**Preflight dependency check pattern** (`scripts/regen-fixtures.sh` does NOT have this; the RESEARCH.md pattern is authoritative here — see Shared Patterns below).

**mktemp -d + trap EXIT** (`tests/lib/sandbox.sh` lines 35–36):
```bash
SANDBOX_DIR="$(mktemp -d)"
trap 'rm -rf "$SANDBOX_DIR"' EXIT
```

`record-demo.sh` must use the same pattern with its own variable name (`DEMO_DIR`):
```bash
DEMO_DIR="$(mktemp -d)"
CAST_FILE="$DEMO_DIR/demo.cast"
GIF_FILE="$DEMO_DIR/demo.gif"
trap 'rm -rf "$DEMO_DIR"' EXIT
```

Note: `sandbox_setup()` uses `trap 'rm -rf' EXIT` (process-level). `regen-fixtures.sh` uses `trap 'rm -rf "$seed"' RETURN` (function-level). `record-demo.sh` is a top-level script with no nested function for the temp dir — use `EXIT` (same as `sandbox.sh`).

**Seed file writing pattern** (`scripts/regen-fixtures.sh` lines 41–43):
```bash
ts-next|node-nest|monorepo|polyglot)
  printf '{"name":"fixture","version":"0.0.0"}\n' > "$seed/package.json"
  ;;
```

`record-demo.sh` must write a ts-next seed (`package.json`) into `$DEMO_DIR` before the expect script runs. Copy this exact `printf` pattern — no `echo`, no heredoc.

**Printf-based progress reporting** (`scripts/regen-fixtures.sh` lines 116, 131):
```bash
printf '[regen] %s\n' "$p"
...
printf '[regen] %s done\n' "$p"
```

`record-demo.sh` uses `[record-demo]` prefix. No `echo`, use `printf` throughout.

**Inline expect script writing** — write the `.exp` file into `$DEMO_DIR` using `cat > "$DEMO_DIR/demo.exp" <<'EXPECT_SCRIPT' ... EXPECT_SCRIPT`. This is standard POSIX here-doc usage inside a bash script (distinct from the Write-tool prohibition, which applies only to the pattern mapper itself). Alternatively use multiple `printf` calls like `regen-fixtures.sh` uses for `_write_seed_claude`. Either approach is acceptable; `cat <<'HEREDOC'` is cleaner for multi-line TCL content.

---

### `.github/assets/demo.gif` (binary artifact, file-I/O)

**No code analog.** This is a binary file produced by `agg` and copied into `.github/assets/` by `record-demo.sh`. The only pattern is directory convention:

**Directory convention** (confirmed by `ls .github/assets/`):
```
.github/assets/
└── logo.svg    ← existing binary/text asset
```

`demo.gif` follows the same convention: committed directly, no build step, referenced from README via relative path. The `mkdir -p "$ASSETS_DIR"` guard in `record-demo.sh` is correct defensive practice even though the directory already exists.

---

### `README.md` (docs, static embed — self-modification)

**Target:** Lines 63–76 of `README.md` — the Quickstart code block.

**Current state** (`README.md` lines 63–76):
```markdown
## 🚀 Quickstart

```bash
# 1. Install
curl -sSL https://raw.githubusercontent.com/mohandoz/conjure/main/install.sh | bash

# 2. Initialize a project (auto-detects new or existing)
cd /path/to/your/repo
conjure init existing --profile=python-fastapi .

# 3. Open Claude Code, paste PROMPT.md, watch the daemon obey
```

That's it. Run `conjure audit` anytime to verify health.
```

**Target state** — replace lines 65–74 (the fenced code block only) with the GIF embed. Keep line 63 (`## 🚀 Quickstart`) and line 76 (`That's it. Run...`) intact:

```markdown
## 🚀 Quickstart

<div align="center">
<img src=".github/assets/demo.gif" alt="conjure init --dry-run --profile=ts-next . then conjure audit" width="700"/>

*`conjure init --dry-run --profile=ts-next .` — zero mutations, fully auditable.*
</div>

That's it. Run `conjure audit` anytime to verify health.
```

Notes for the planner:
- The caption text is locked (D-10): `*\`conjure init --dry-run --profile=ts-next .\` — zero mutations, fully auditable.*`
- Width 700 is set by RESEARCH.md; do not change it.
- The `<div align="center">` wrapper is required — GitHub markdown does not support `align` on `<img>` alone.
- The three-step `# 1. Install … # 3. Open Claude Code` block is removed; the GIF replaces it.
- The `That's it. Run \`conjure audit\`` sentence (line 76) stays immediately after `</div>`.

---

### `.github/workflows/ci.yml` (config, CI assertion — self-modification)

**Target:** `test` job, after the "Run kit test suite" step (line 31).

**Existing step to insert after** (`ci.yml` lines 30–31):
```yaml
      - name: Run kit test suite
        run: bash tests/run.sh
```

**Step to insert** (RESEARCH.md Pattern 5 / D-08):
```yaml
      - name: Assert demo GIF committed
        run: test -s .github/assets/demo.gif
```

**Surrounding context for precise placement** (`ci.yml` lines 30–34):
```yaml
      - name: Run kit test suite
        run: bash tests/run.sh

      - name: Audit script smoke
        run: bash scripts/audit-setup.sh . || true
```

The new step goes between "Run kit test suite" and "Audit script smoke". This matches the logical grouping: file-existence checks belong with the test suite, not with the audit smoke test.

**Indentation pattern:** Two spaces for step-level indent (`      - name:`), four spaces for `run:` value. Exact YAML indentation from existing steps must be preserved — `run: test -s ...` is a single-line value.

**No new job:** The check is added to the `test` job only. Do not create `demo-gif-check:` as a separate job. (D-08)

---

## Shared Patterns

### Preflight Dependency Check (for `record-demo.sh`)
**Source:** RESEARCH.md Pattern 3 (no exact codebase analog — `regen-fixtures.sh` has no preflight check)
**Apply to:** `scripts/record-demo.sh` only
```bash
for dep in asciinema agg expect; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    printf 'record-demo.sh: %s is required but not found.\n' "$dep" >&2
    printf '  macOS:  brew install %s\n' "$dep" >&2
    exit 1
  fi
done
```

The closest codebase analog for this pattern is `scripts/preflight.sh`. Confirm it follows `command -v` style consistent with CLAUDE.md constraints (POSIX bash 3.2+, no bash 4+ features).

### mktemp + trap EXIT (shared between `sandbox.sh` and `record-demo.sh`)
**Source:** `tests/lib/sandbox.sh` lines 35–36
**Apply to:** `scripts/record-demo.sh`
```bash
DEMO_DIR="$(mktemp -d)"
trap 'rm -rf "$DEMO_DIR"' EXIT
```

### printf for output (no echo)
**Source:** `scripts/regen-fixtures.sh` throughout (lines 29, 109, 116, 131)
**Apply to:** `scripts/record-demo.sh`
```bash
printf '[record-demo] demo.gif written to %s\n' "$ASSETS_DIR/demo.gif"
printf '[record-demo] File size: %s bytes\n' "$(wc -c < "$ASSETS_DIR/demo.gif")"
```

### CONJURE_HOME resolution
**Source:** `scripts/regen-fixtures.sh` lines 10–11
**Apply to:** `scripts/record-demo.sh`
```bash
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
```

All path variables derive from `CONJURE_HOME`, never from `pwd` or `$HOME`.

### PATH isolation for subprocess
**Source:** `tests/lib/sandbox.sh` lines 44–45
**Apply to:** `scripts/record-demo.sh` — export `PATH` before calling `expect` so the spawned `asciinema` shell can find the `conjure` CLI:
```bash
export PATH="$CONJURE_HOME/cli:$PATH"
```
This prevents Pitfall 4 ("conjure: command not found" inside the asciinema recording). The sandbox.sh version is more elaborate (resolves node dir); `record-demo.sh` only needs the cli path prepended.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/assets/demo.gif` | binary artifact | file-I/O | Binary output of `agg`; no code pattern applies. Directory convention established by `logo.svg`. |

---

## Key Anti-Patterns (from RESEARCH.md — must be communicated to planner)

These are failure modes with high probability; the planner must encode them as explicit constraints in the plan:

1. **DO NOT use `--cols`/`--rows` with asciinema 3.x.** Use `--window-size 120x35`. [VERIFIED]
2. **DO NOT use `asciinema rec -c expect_script.sh`.** The expect script must use `spawn asciinema rec` internally. [VERIFIED]
3. **DO NOT use `echo` for output.** Project convention is `printf` throughout all `scripts/` files.
4. **DO NOT set `trap RETURN` for DEMO_DIR cleanup.** `record-demo.sh` is not a function — use `trap EXIT`.
5. **DO NOT install asciinema/agg/expect in CI.** The `test -s` check requires only that the file was committed.

---

## Metadata

**Analog search scope:** `scripts/`, `tests/lib/`, `.github/workflows/`, `README.md`, `.github/assets/`
**Files scanned:** 6 (`regen-fixtures.sh`, `sandbox.sh`, `ci.yml`, `README.md`, `preflight.sh` referenced, `logo.svg` directory check)
**Pattern extraction date:** 2026-05-25
