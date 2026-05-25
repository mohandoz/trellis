<!-- Covers: TECH-02a | SAFE-03, SAFE-04 -->
# Phase 01 VALIDATION

## Verify preflight exits 0 in normal environment

```bash
CONJURE_HOME=$(pwd) bash scripts/preflight.sh
echo "exit: $?"
```

**Expected:** `exit: 0` — all required deps present, no error output

## Verify preflight blocks when node is missing

```bash
STRIPPED_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r dir; do
  [ -x "$dir/node" ] || printf '%s\n' "$dir"
done | tr '\n' ':' | sed 's/:$//')"
PATH="$STRIPPED_PATH" bash scripts/preflight.sh
echo "exit: $?"
```

**Expected:** `exit: [^0]` — non-zero exit (node is a required dep; any digit 1-9 is correct)

## Verify preflight emits OS-aware package manager fix-it hint

```bash
STRIPPED_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r dir; do
  [ -x "$dir/node" ] || printf '%s\n' "$dir"
done | tr '\n' ':' | sed 's/:$//')"
PATH="$STRIPPED_PATH" bash scripts/preflight.sh 2>&1 || true
```

**Expected:** output contains `brew` (macOS), `apt` (Linux/WSL), or `winget` (Windows Git Bash) — pipe to `grep -E 'brew|apt|winget'` to confirm

## Verify settings.json.tmpl uses node hook wiring (not bash)

```bash
grep -c 'node .claude/hooks/' templates/settings.json.tmpl
grep -v '^#' templates/settings.json.tmpl | grep -c 'bash .claude/hooks/' || true
```

**Expected:** first count >= 1 (node hooks present); second count = 0 (no bash hooks — SAFE-03)

## Verify init-project.sh sources hooks-nodejs and has no chmod on hook files

```bash
grep 'hooks-nodejs' scripts/init-project.sh
grep -v '^#' scripts/init-project.sh | grep -c 'chmod.*hooks' || true
```

**Expected:** hooks-nodejs line present (e.g. `for hook in "$KIT"/templates/hooks-nodejs/`); chmod count = 0 (no chmod on .mjs hook files)
