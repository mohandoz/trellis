<!-- Covers: TECH-02c | TEST-03, TEST-05, TEST-06, TEST-07 -->

# Phase 04 VALIDATION

## Verify all green fixtures audit exit 0 (TEST-03, TEST-05)

```bash
CONJURE_HOME=$(pwd)
for fx in tests/fixtures/[^_]*/; do
  prof=$(basename "$fx")
  TMPDIR=$(mktemp -d)
  cp -r "$fx/." "$TMPDIR/"
  AUDIT_OUT=$(bash scripts/audit-setup.sh "$TMPDIR" 2>&1)
  rc=$?
  rm -rf "$TMPDIR"
  [ "$rc" -eq 0 ] && echo "PASS: $prof" || echo "FAIL: $prof (rc=$rc)"
done
```

**Expected:** `PASS:` line for each profile; no `FAIL:` lines.

## Verify _broken fixture audit exits non-zero (TEST-07)

```bash
CONJDIR=$(pwd)
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
cp -r tests/fixtures/_broken/. "$TMPDIR/"
bash scripts/audit-setup.sh "$TMPDIR" 2>&1
echo "exit: $?"
```

**Expected:** `exit: [^0]` (non-zero exit code) and output containing text from tests/fixtures/_broken/EXPECT.

## Verify dry-run leaves fixture tree byte-identical (TEST-05)

```bash
CONJURE_HOME=$(pwd)
ORIG=$(mktemp -d); SNAP=$(mktemp -d)
trap 'rm -rf "$ORIG" "$SNAP"' EXIT
cp -r tests/fixtures/python-fastapi/. "$ORIG/"
cp -r tests/fixtures/python-fastapi/. "$SNAP/"
cli/conjure init --dry-run "$SNAP" >/dev/null 2>&1 || true
diff -r "$SNAP" "$ORIG" && echo "PASS: byte-identical" || echo "FAIL: diff found"
```

**Expected:** `PASS: byte-identical`

## Verify audit detects CLAUDE.md size cap violation (TEST-07 FM-1)

```bash
TMPDIR=$(mktemp -d); trap 'rm -rf "$TMPDIR"' EXIT
printf '# size-cap test\n' > "$TMPDIR/CLAUDE.md"
for i in $(seq 1 205); do printf '# filler %s\n' "$i" >> "$TMPDIR/CLAUDE.md"; done
bash scripts/audit-setup.sh "$TMPDIR" 2>&1 | grep -i "HARD CAP exceeded"
```

**Expected:** line containing `HARD CAP exceeded`
