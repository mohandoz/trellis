<!-- Covers: TECH-02b | SAFE-01, SAFE-02, D-04, D-05 -->
# Phase 02 VALIDATION

## Verify --dry-run creates no filesystem artifacts (SAFE-01)

```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# Test project\n' > "$TMPDIR/CLAUDE.md"
CONJURE_HOME=$(pwd) cli/conjure init --dry-run "$TMPDIR" >/dev/null 2>&1 || true
[ -d "$TMPDIR/.claude" ] && echo "FAIL: .claude created" || echo "PASS: no .claude"
```

**Expected:** `PASS: no .claude` — dry-run must not create any filesystem artifacts

## Verify [dry-run] prefix lines appear in output (D-04)

```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# Test project\n' > "$TMPDIR/CLAUDE.md"
CONJURE_HOME=$(pwd) cli/conjure init --dry-run "$TMPDIR" 2>&1 | grep '\[dry-run\]' | head -3
```

**Expected:** one or more lines containing `[dry-run]` — e.g. `[dry-run] would mkdir .claude/skills`

## Verify mutation count > 0 in dry-run summary line (D-05)

```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# Test project\n' > "$TMPDIR/CLAUDE.md"
CONJURE_HOME=$(pwd) cli/conjure init --dry-run "$TMPDIR" 2>&1 | grep -E '\[dry-run\] [1-9][0-9]* mutations skipped'
```

**Expected:** line matching `[dry-run] N mutations skipped` where N >= 1

## Verify lib/mutate.sh DRY_RUN=1 suppresses mkdir and write (SAFE-02)

```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
source lib/mutate.sh
DRY_RUN=1 mutate_mkdir "$TMPDIR/would-not-exist"
[ -d "$TMPDIR/would-not-exist" ] && echo "FAIL: dir created" || echo "PASS: mkdir suppressed"
DRY_RUN=1 mutate_write "$TMPDIR/would-not-exist.txt" "content"
[ -f "$TMPDIR/would-not-exist.txt" ] && echo "FAIL: file written" || echo "PASS: write suppressed"
```

**Expected:** `PASS: mkdir suppressed` and `PASS: write suppressed`
