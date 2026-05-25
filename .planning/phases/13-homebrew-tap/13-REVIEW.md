---
phase: 13-homebrew-tap
reviewed: 2026-05-26T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Formula/conjure.rb
  - cli/conjure
  - .github/workflows/release.yml
  - tests/run.sh
findings:
  critical: 2
  warning: 5
  info: 2
  total: 9
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-05-26
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This phase introduces the Homebrew tap infrastructure: `Formula/conjure.rb`, automation in `.github/workflows/release.yml`, homebrew-specific tests in `tests/run.sh` (BREW-01 through BREW-04), and review of the existing `cli/conjure` for Homebrew-installation correctness.

The Formula structure is sound and the release automation is mostly correct. Two blockers require immediate attention: the Formula's `sha256` is a literal placeholder string that will cause `brew install` to fail (checksum mismatch) for anyone who tries to install before the bump action fires, and the formula URL hard-codes `v0.3.0` while the `VERSION` file currently reads `0.2.1` — meaning the referenced tarball does not yet exist. There are also notable gaps in the workflow (unpinned third-party actions, no release-notes validation) and in `cli/conjure` (the `migrate` subcommand bypasses the preflight check when dispatched directly).

---

## Critical Issues

### CR-01: Formula sha256 is a placeholder string — `brew install` will fail

**File:** `Formula/conjure.rb:5`
**Issue:** `sha256 "PLACEHOLDER_SHA256_REPLACE_ON_FIRST_RELEASE"` is shipped as a real string. When any user runs `brew install conjure` against this formula before the `mislav/bump-homebrew-formula-action` has run and updated it, Homebrew will fetch the tarball, compute its real SHA-256, compare against the literal placeholder, and abort with a checksum mismatch error. The formula is currently non-installable.

The `mislav/bump-homebrew-formula-action` does rewrite this field in the Homebrew tap repo (`mohandoz/homebrew-conjure`), but the formula committed to the **main source repo** remains a placeholder indefinitely, misleading anyone who reads or copies it.

Additionally, the test suite (BREW-01 through BREW-04 in `tests/run.sh`) does not include a check for the placeholder sha256, so CI will pass while the formula is broken.

**Fix:**
After the first release is cut and the tap PR merges, backport the real SHA into this file. Until then, add a test assertion:
```bash
# In tests/run.sh BREW section:
if grep -q 'PLACEHOLDER' "$CONJURE_HOME/Formula/conjure.rb"; then
  fail "Formula/conjure.rb sha256 is still a placeholder — update before release (BREW-01)"
else
  pass "Formula/conjure.rb sha256 is not a placeholder (BREW-01)"
fi
```

---

### CR-02: Formula URL targets v0.3.0 but VERSION file is 0.2.1 — tarball does not exist

**File:** `Formula/conjure.rb:4`
**Issue:** The formula pins the download URL to `v0.3.0`:
```
url "https://github.com/mohandoz/conjure/archive/refs/tags/v0.3.0.tar.gz"
```
But the `VERSION` file contains `0.2.1`. No `v0.3.0` tag has been pushed to GitHub, so the URL resolves to a 404. Any attempt to install or test this formula (e.g., `brew audit`, `brew install`) will fail at download.

The release workflow's "Verify VERSION matches tag" step checks that `VERSION` matches the pushed tag — but that check runs only at tag push time, not against the formula URL. This discrepancy is invisible to CI.

**Fix:** The formula URL must match the current `VERSION` file exactly. Until `v0.3.0` is the real released version, the formula should reference the most recently released tag (`v0.2.1` or whatever the latest is). The `mislav/bump-homebrew-formula-action` will update it automatically on the next release.

Add a test to catch future drift:
```bash
FORMULA_VER="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$CONJURE_HOME/Formula/conjure.rb" | head -1 | tr -d 'v')"
REPO_VER="$(cat "$CONJURE_HOME/VERSION")"
if [ "$FORMULA_VER" = "$REPO_VER" ]; then
  pass "Formula URL version matches VERSION file (BREW-01)"
else
  fail "Formula URL version ($FORMULA_VER) != VERSION ($REPO_VER) — tarball missing (BREW-01)"
fi
```

---

## Warnings

### WR-01: GitHub Actions not pinned to commit SHAs — supply chain risk

**File:** `.github/workflows/release.yml:14,37,44`
**Issue:** All three third-party actions are pinned to mutable version tags rather than immutable commit SHAs:
```yaml
- uses: actions/checkout@v4
- uses: softprops/action-gh-release@v2
- uses: mislav/bump-homebrew-formula-action@v3
```
If any of these tags are moved (maliciously or by accident), the release pipeline silently executes different code. `mislav/bump-homebrew-formula-action` uses `COMMITTER_TOKEN` (write access to the tap repo) — a compromised action could exfiltrate the token or push malicious formula content.

**Fix:** Pin to verified commit SHAs:
```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: softprops/action-gh-release@e7a8f85e1c67a31e6ed99a94b41bd0b71bbee6b2  # v2.3.2
- uses: mislav/bump-homebrew-formula-action@b3327118b2153c82da63fd9cbf58942146ee99f0  # v3.3.0
```
Run `dependabot` or `pin-github-actions` to maintain these automatically.

---

### WR-02: Release pipeline silently publishes with empty release notes

**File:** `.github/workflows/release.yml:26-39`
**Issue:** The `Extract CHANGELOG entry` step runs `awk` to find the section for the pushed tag in `CHANGELOG.md`. If the tag has no corresponding entry (misspelled version, unreleased tag, etc.), `awk` produces an empty `release-notes.md`. The step exits 0, and `softprops/action-gh-release` publishes a GitHub release with a blank description. There is no validation step that checks whether the extracted notes are non-empty.

**Fix:** Add a non-empty guard after the awk extraction:
```yaml
- name: Extract CHANGELOG entry
  id: cl
  run: |
    tag="${GITHUB_REF#refs/tags/v}"
    awk -v ver="$tag" '
      $0 ~ "^## \\[" ver "\\]" { capture=1; next }
      capture && /^## \[/      { exit }
      capture                  { print }
    ' CHANGELOG.md > release-notes.md
    if [ ! -s release-notes.md ]; then
      echo "ERROR: No CHANGELOG entry found for v${tag}" >&2
      exit 1
    fi
```

---

### WR-03: `conjure migrate` dispatched directly skips preflight check

**File:** `cli/conjure:120-140` and `cli/conjure:326`
**Issue:** When called as `conjure migrate from-claude`, the dispatch at line 326 goes directly to `cmd_migrate`. That function runs the migration script immediately with no `cmd_preflight` call. In contrast, `conjure init` (which calls `cmd_migrate` internally for `init migrate`) does call `cmd_preflight` first (line 75).

Running a migration without verifying prerequisites (node, jq, git, shellcheck) can produce confusing mid-run failures deep inside the migration scripts rather than a clean preflight error.

**Fix:** Add `cmd_preflight || return 1` to `cmd_migrate` before executing the migration script:
```bash
cmd_migrate() {
  local source="${1:-}" target="${2:-$(pwd)}" dryrun="${3:-0}"
  [ -z "$source" ] && { echo "Usage: conjure migrate <source> [target]"; return 1; }

  cmd_preflight || return 1   # <-- add this

  local script="$CONJURE_HOME/migrations/$source/migrate.sh"
  ...
```

---

### WR-04: `DRY_RUN` assigned but not exported before `source lib/mutate.sh`

**File:** `cli/conjure:68-69`
**Issue:** In `cmd_init`, `DRY_RUN` is set as a plain shell variable at line 68 and then `lib/mutate.sh` is sourced at line 69. `mutate.sh` reads `${DRY_RUN:-0}` — since it is sourced (not spawned) into the same shell process, the variable is visible. However, `DRY_RUN` is never `export`ed in the CLI, which is inconsistent with how it is passed to subprocesses: all subprocess calls use `DRY_RUN="$dryrun"` as an inline env prefix (lines 82, 87, 92, 139). This means if a sourced library spawns a subshell (e.g., command substitution), the subshell will not inherit `DRY_RUN`.

For `lib/mutate.sh` itself this is currently safe because it reads `${DRY_RUN:-0}` inline. But the pattern is fragile and will silently enable live mutations in subshells if any sourced library is extended to spawn subprocesses.

**Fix:** Export `DRY_RUN` immediately after setting it, before sourcing any library:
```bash
DRY_RUN="$dryrun"
export DRY_RUN
source "$CONJURE_HOME/lib/mutate.sh" \
  || { echo "✗ Failed to load lib/mutate.sh ..."; return 1; }
```

---

### WR-05: Trap management in test loop leaves stale temp dirs on unexpected failure

**File:** `tests/run.sh:256-268` (and similar patterns at lines 300-313, 495, 604)
**Issue:** In loops that iterate over fixtures, `sandbox_setup` is called first (it registers `trap 'rm -rf "$SANDBOX_DIR"' EXIT` internally), then the caller immediately overwrites it with an identical `trap 'rm -rf "$SANDBOX_DIR"' EXIT` (line 257). The single-quoted `$SANDBOX_DIR` in the trap string is evaluated at **fire time**, not at registration time.

If the script is killed or exits with an error midway through iteration N, the trap fires and cleans up only the current iteration's `SANDBOX_DIR`. All previous iterations that already ran `rm -rf "$SANDBOX_DIR"; trap - EXIT` are gone (correct). But if the test exits before the manual `rm -rf` on a given iteration (e.g., a subcommand raises an unexpected error under `set -uo pipefail`), only the last registered `SANDBOX_DIR` value is cleaned up.

More concretely: once `sandbox_setup` is called for iteration N+1, the trap variable resolves to iteration N+1's directory. Iteration N's directory (which was set as `$SANDBOX_DIR` at registration time but single-quoted) is never cleaned up on unexpected exit.

**Fix:** Capture the directory in a local variable at registration time using double-quotes, or clean up explicitly at each iteration's exit path:
```bash
# Double-quote to capture at registration time:
_trap_dir="$SANDBOX_DIR"
trap 'rm -rf "$_trap_dir"' EXIT
```
Alternatively, ensure every code path within the loop hits `rm -rf "$SANDBOX_DIR"` (including error paths) before looping to the next fixture.

---

## Info

### IN-01: Formula `test do` block is minimal — does not validate core functionality

**File:** `Formula/conjure.rb:19-21`
**Issue:** The Homebrew `test do` block only runs `conjure version`. Homebrew runs this block during `brew test conjure` to smoke-test the installed package. The current test confirms the binary is executable and the version reads correctly, but does not verify that the installed kit (profiles, templates, scripts) is intact at `CONJURE_HOME`. A broken `share/conjure/` directory would pass the test.

**Fix:** Extend the `test do` block to verify at least one core path:
```ruby
test do
  system bin/"conjure", "version"
  system bin/"conjure", "preflight"
end
```
Or check that key directories exist:
```ruby
test do
  system bin/"conjure", "version"
  assert_predicate share/"conjure/templates", :exist?
  assert_predicate share/"conjure/profiles",  :exist?
end
```

---

### IN-02: `cmd_help <subcommand>` prints raw function body, not user-facing help text

**File:** `cli/conjure:313-321`
**Issue:** `conjure help init` uses `sed` to extract the `cmd_init()` function body from `$0` and prints the first 20 lines of raw bash source. For thin wrappers like `cmd_refresh_graph` (two lines), this is useless. For complex functions like `cmd_init` (60+ lines), it prints bash code, not documentation.

This is a pre-existing issue but is now more visible as `cli/conjure` is distributed via Homebrew to end users who expect `help <subcommand>` to produce human-readable output.

**Fix:** Add a `# Usage:` comment block inside each command function that `cmd_help` extracts, or replace the `sed` approach with a here-doc help strings per subcommand.

---

_Reviewed: 2026-05-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
