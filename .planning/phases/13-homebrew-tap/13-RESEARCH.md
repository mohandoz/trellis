---
phase: 13
slug: homebrew-tap
status: draft
researched: 2026-05-26
---

# Phase 13: Homebrew Tap — Research

**Researched:** 2026-05-26
**Domain:** Homebrew formula authoring, tap repo structure, GitHub Actions auto-bump
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Formula file lives at `Formula/conjure.rb` in THIS repo (mohandoz/conjure). The tap repo `mohandoz/homebrew-conjure` is a separate GitHub repo containing only `Formula/conjure.rb`. The bump action copies/PRs the updated formula there.
- **D-02:** Formula references a tagged tarball URL (`https://github.com/mohandoz/conjure/archive/refs/tags/v<VERSION>.tar.gz`) + SHA256. Never a branch HEAD. Enforced by BREW-03.
- **D-03:** In `cli/conjure`, change line 24 from `CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"` to `CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"`.
- **D-04:** Formula installs a wrapper script at `bin/conjure` that exports `CONJURE_HOME="#{share}/conjure"` before exec-ing `#{share}/conjure/cli/conjure`. No other changes to `cli/conjure` beyond D-03.
- **D-05:** Do NOT call `brew --prefix` inside `cli/conjure` at runtime.
- **D-06:** Formula installs: `bin/conjure` (wrapper), `share/conjure/cli/conjure` (real CLI), `share/conjure/` containing `profiles/`, `compliance/`, `migrations/`, `templates/`, `lib/`, `scripts/`, `VERSION`. NOT installed: `tests/`, `.planning/`, `.github/`, `CHANGELOG.md`, `Formula/`.
- **D-07:** `mislav/bump-homebrew-formula-action@v3` fires in `.github/workflows/release.yml` after the existing "Create release" step. Needs `HOMEBREW_TAP_GITHUB_TOKEN` secret with `repo` write access to `mohandoz/homebrew-conjure`.
- **D-08:** Bump action config: `formula-name: conjure`, `tap-repo: mohandoz/homebrew-conjure`, `download-url: https://github.com/mohandoz/conjure/archive/refs/tags/${{ github.ref_name }}.tar.gz`.

### Claude's Discretion

- Exact Ruby DSL idioms in `conjure.rb` (test block, depends_on, etc.)
- Whether bump action uses `commit-message:` override or default format
- Whether VALIDATION.md test for BREW-01 is automated (formula syntax check) or documented as manual
- shellcheck exemption patterns needed for any new bash in formula wrapper (inline shell in Ruby heredoc is not shellchecked by CI)

### Deferred Ideas (OUT OF SCOPE)

- `brew test conjure` beyond `--version` check
- macOS-only formula features (`on_macos { ... }`)
- Pinning bump action to exact SHA (Phase 15 hardening concern)
- `brew bottle` binary bottle creation
- Formula `depends_on "shellcheck"`
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BREW-01 | `brew install mohandoz/conjure/conjure` succeeds; `conjure --version` exits 0 | Formula DSL section; wrapper pattern; test block |
| BREW-02 | `CONJURE_HOME` resolves to `$(brew --prefix)/share/conjure/` automatically | D-03 one-line edit; wrapper sets env var before exec; unit test pattern |
| BREW-03 | Formula pinned to tagged tarball URL + SHA256, never branch HEAD | URL DSL pattern; static grep test confirms absence of `branch`/`HEAD` |
| BREW-04 | `mislav/bump-homebrew-formula-action@v3` fires on every GitHub release to auto-update SHA256 | Action inputs confirmed; secret name confirmed; release.yml extension |
</phase_requirements>

---

## Summary

Phase 13 publishes Conjure as a Homebrew tap formula. The work has five concrete artifacts: a one-character change to `cli/conjure` line 24, a new `Formula/conjure.rb`, a new step in `.github/workflows/release.yml`, BREW regression tests appended to `tests/run.sh`, and `13-VALIDATION.md`. All five have established analogs in the codebase (see `13-PATTERNS.md`); the only genuinely new domain is the Homebrew Ruby DSL.

The Homebrew wrapper pattern is well-understood: install all runtime files under `share/conjure/`, then write a one-line `bin/conjure` wrapper script that sets `CONJURE_HOME` before exec-ing the real dispatcher. This is the standard `write_env_script` / hand-written heredoc approach used throughout homebrew-core for bash CLI tools. The critical implementation detail is that `write_env_script` from Homebrew's `Pathname` extension generates exactly this pattern, but a hand-written heredoc is equally valid and clearer to read.

The `mislav/bump-homebrew-formula-action` is at v4.1 (latest) as of research date. The CONTEXT.md specifies `@v3` — v3.6 is the latest patch of the v3 series and the tag still resolves. No inputs changed between v3 and v4 that affect this usage; v4 changed the underlying Node.js runtime from 20 to 24 internally. Using `@v3` as locked is safe and compliant with the decision.

**Primary recommendation:** Implement exactly as specified in CONTEXT.md — no alternative approaches are needed. The formula wrapper + `write` heredoc pattern is standard, battle-tested, and requires no external dependencies beyond the Homebrew DSL itself.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Package distribution | CI/CD pipeline | Tap repo (passive) | Release YAML drives all automation; tap repo is a data store, not logic |
| CONJURE_HOME resolution | Formula wrapper script (bin/conjure) | cli/conjure conditional | Wrapper sets env before exec; cli/conjure falls back only when env unset |
| SHA256 computation | bump action (auto-calculated) | — | Action fetches tarball and computes sha256 at release time |
| Tap formula hosting | mohandoz/homebrew-conjure repo | Formula/conjure.rb in main repo | Tap repo is the authoritative install source; main repo holds the template |
| Regression test coverage | tests/run.sh bash runner | — | Consistent with all existing test coverage in this project |

---

## Standard Stack

### Core

This phase installs no npm packages and no new runtime dependencies. The "stack" is the Homebrew Ruby DSL and one GitHub Action.

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Homebrew formula Ruby DSL | Homebrew 5.x (local: 5.1.13) | Package distribution | Only mechanism for `brew install` |
| `mislav/bump-homebrew-formula-action` | `@v3` (locked by D-07; latest v3 patch: v3.6) | Auto-update SHA256 in tap | Standard action for Homebrew tap auto-bump; widely used |
| `softprops/action-gh-release` | `@v2` (already in release.yml) | Create GitHub release | Already present; bump step fires after it |

### No New npm/pip/cargo Packages

This phase adds no installable packages. `Formula/conjure.rb` is a Ruby file interpreted by the end user's Homebrew installation. No `pip install`, `npm install`, or `cargo install` commands run in CI for this phase.

---

## Package Legitimacy Audit

No new packages are installed by this phase in CI. The only external dependency added to `.github/workflows/release.yml` is the GitHub Action `mislav/bump-homebrew-formula-action@v3`.

| Component | Registry | Notes | slopcheck | Disposition |
|-----------|----------|-------|-----------|-------------|
| `mislav/bump-homebrew-formula-action@v3` | GitHub Actions Marketplace | Action by @mislav (Homebrew core contributor); 6+ years old; confirmed via GitHub API — tags v3.0 through v3.6 exist | N/A (not npm) | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

slopcheck was available (v0.6.1) but not applicable — no npm/pip/cargo packages are introduced. The GitHub Action was verified by fetching its `action.yml` directly from the repository and cross-referencing with the GitHub Marketplace listing.

---

## Architecture Patterns

### System Architecture Diagram

```
GitHub tag push (v*)
        |
        v
release.yml (ubuntu-latest)
  [1] checkout
  [2] verify VERSION == tag
  [3] extract CHANGELOG entry
  [4] softprops/action-gh-release@v2  ──> creates GitHub Release
        |                                  (tarball auto-published at
        |                                   .../archive/refs/tags/v*.tar.gz)
        v
  [5] mislav/bump-homebrew-formula-action@v3
        |  reads: COMMITTER_TOKEN (secret)
        |  reads: tarball URL from download-url input
        |  computes: SHA256 of tarball (fetched over HTTPS)
        |  writes: PR or direct push to mohandoz/homebrew-conjure
        v
mohandoz/homebrew-conjure
  Formula/conjure.rb  (url + sha256 updated)
        |
        v
end user: brew install mohandoz/conjure/conjure
  brew fetches tarball from GitHub
  brew extracts to Cellar/conjure/VERSION/
        |
        v
Formula#install block runs:
  share.install "cli", "scripts", ...  --> $(brew --prefix)/Cellar/conjure/VERSION/share/conjure/
  bin/conjure (heredoc wrapper)        --> $(brew --prefix)/Cellar/conjure/VERSION/bin/conjure
        |
        v
User runs: conjure version
  bin/conjure wrapper sets CONJURE_HOME=$(brew --prefix)/Cellar/conjure/VERSION/share/conjure
  execs share/conjure/cli/conjure
  cli/conjure reads $CONJURE_HOME/VERSION  --> prints "conjure 0.3.0"
```

### Recommended Project Structure (new files only)

```
conjure/
├── Formula/
│   └── conjure.rb          # Homebrew formula template (authoritative)
├── cli/
│   └── conjure             # line 24: CONJURE_HOME conditional (D-03)
└── .github/workflows/
    └── release.yml         # append bump-homebrew-formula-action step (D-07)
```

Tap repo (separate GitHub repo `mohandoz/homebrew-conjure`):
```
homebrew-conjure/
├── Formula/
│   └── conjure.rb          # copy of Formula/conjure.rb from main repo (maintained by bump action)
└── README.md               # installation instructions (optional but recommended)
```

---

## Exact Ruby DSL for `Formula/conjure.rb`

[VERIFIED: Homebrew Formula Cookbook + Homebrew source pathname.rb]

```ruby
class Conjure < Formula
  desc "Missing init kit for Claude Code — scaffolds a four-layer harness in one command"
  homepage "https://github.com/mohandoz/conjure"
  url "https://github.com/mohandoz/conjure/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  def install
    # Install all runtime dirs under share/conjure/
    # Tests, planning, and CI dirs are excluded (not present in source tarball install block)
    share.install "cli", "scripts", "profiles", "compliance",
                  "migrations", "templates", "lib", "VERSION"

    # Wrapper script: sets CONJURE_HOME to this keg's share/conjure before exec-ing real CLI
    # write_env_script alternative — heredoc is clearer for a single env var
    (bin/"conjure").write <<~SH
      #!/bin/bash
      export CONJURE_HOME="#{share}/conjure"
      exec "#{share}/conjure/cli/conjure" "$@"
    SH
  end

  test do
    system bin/"conjure", "version"
  end
end
```

**Key DSL facts** [VERIFIED: Homebrew Formula Cookbook, docs.brew.sh]:

- `share` resolves to `#{prefix}/share` = `$(brew --prefix)/Cellar/conjure/VERSION/share` at install time; the symlink farm makes it accessible as `$(brew --prefix)/share/conjure/` from outside.
- `share.install "cli"` copies the `cli/` directory as `share/cli/` — NOT `share/conjure/cli/`. The correct idiom to get `share/conjure/cli/` is to install into a `conjure` subdirectory of share: use `(share/"conjure").install "cli", "scripts", ...` instead of `share.install`.
- `(bin/"conjure").write <<~SH ... SH` writes a file at `bin/conjure` with the heredoc content and automatically sets the executable bit.
- The `#{share}` interpolation inside the heredoc expands to the absolute path at install time (Ruby string interpolation), producing a hardcoded path in the wrapper — this is intentional and standard Homebrew practice.
- `license "MIT"` uses an SPDX identifier. Homebrew requires a license field.
- No `depends_on` entries are needed — bash and the stdlib are available on macOS/Linux without explicit deps.

**Corrected install block (critical fix — see Pitfall 1):**

```ruby
def install
  (share/"conjure").install "cli", "scripts", "profiles", "compliance",
                             "migrations", "templates", "lib", "VERSION"

  (bin/"conjure").write <<~SH
    #!/bin/bash
    export CONJURE_HOME="#{share}/conjure"
    exec "#{share}/conjure/cli/conjure" "$@"
  SH
end
```

---

## `mislav/bump-homebrew-formula-action@v3` — Confirmed Inputs

[VERIFIED: action.yml fetched directly from github.com/mislav/bump-homebrew-formula-action]

| Input | Required | Default | Value for this phase |
|-------|----------|---------|----------------------|
| `formula-name` | no | repo name lowercased | `conjure` |
| `formula-path` | no | `Formula/<formula-name>.rb` | omit (default is correct for personal taps) |
| `tag-name` | no | currently pushed tag | omit (default is correct) |
| `download-url` | no | GitHub archive at refs/tags/<tag>.tar.gz | `https://github.com/mohandoz/conjure/archive/refs/tags/${{ github.ref_name }}.tar.gz` |
| `download-sha256` | no | auto-calculated | omit (action fetches and computes) |
| `homebrew-tap` | no | `Homebrew/homebrew-core` | `mohandoz/homebrew-conjure` |
| `push-to` | no | auto-fork | omit (token has direct write; direct push preferred) |
| `base-branch` | no | repo default branch | omit (tap default branch is `main`) |
| `create-pullrequest` | no | smart default | omit (direct push when token has write access) |
| `commit-message` | no | `{{formulaName}} {{version}}\nCreated by...` | omit (default is acceptable) |

**Secret name:** `COMMITTER_TOKEN` — this is the environment variable name the action reads. The GitHub Actions secret can be named anything; the env injection maps it: `env: COMMITTER_TOKEN: ${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}`. The CONTEXT.md uses `HOMEBREW_TAP_GITHUB_TOKEN` as the secret name in the repository, which is clear and specific.

**Token scopes required:** `repo` + `workflow` (classic PAT). Fine-grained PATs also work if scoped to `mohandoz/homebrew-conjure` with `Contents: write`.

**v3 vs v4 status:**
- v3.6 is the latest patch of the v3 series (confirmed via GitHub API: tags include v3.0 through v3.6).
- v4.1 is the current latest (changed internal runtime from Node 20 to Node 24; no input API changes affecting this usage).
- Using `@v3` as specified in D-07 is safe — GitHub Actions resolves `@v3` to the latest v3.x commit automatically.

**Complete workflow step:**

```yaml
      - name: Bump Homebrew formula
        uses: mislav/bump-homebrew-formula-action@v3
        with:
          formula-name: conjure
          homebrew-tap: mohandoz/homebrew-conjure
          download-url: https://github.com/mohandoz/conjure/archive/refs/tags/${{ github.ref_name }}.tar.gz
        env:
          COMMITTER_TOKEN: ${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}
```

Note: the CONTEXT.md `13-PATTERNS.md` uses `tap-repo:` as the input name. The verified action.yml uses `homebrew-tap:`. These are two different input names — the correct name is `homebrew-tap`. The `tap-repo` name does not exist in the action and will be silently ignored.

---

## Files Installed vs Excluded

[VERIFIED: D-06 in CONTEXT.md cross-referenced with repo structure]

**Installed to `share/conjure/`:**

| Directory/File | Reason |
|----------------|--------|
| `cli/` | Contains the real `conjure` dispatcher |
| `scripts/` | Worker scripts called by cli/conjure |
| `profiles/` | Stack profiles applied by `conjure init --profile` |
| `compliance/` | Compliance overlays |
| `migrations/` | Migration scripts |
| `templates/` | Scaffold templates |
| `lib/` | Shared bash libraries (mutate.sh, merge.sh) |
| `VERSION` | Read by cli/conjure to populate `$CONJURE_VERSION` |

**NOT installed (excluded from tarball install block):**

| Directory/File | Reason |
|----------------|--------|
| `tests/` | Development/CI only; not needed at runtime |
| `.planning/` | Development planning artifacts |
| `.github/` | CI configuration; not runtime |
| `CHANGELOG.md` | Not needed at runtime |
| `Formula/` | Self-referential; not a runtime dep |
| `.claude/` | Project-local harness config; not part of the kit |
| `*.md` at root | Docs; not runtime |

**Important:** The GitHub-generated tarball from `archive/refs/tags/v*.tar.gz` does NOT include `.git/`, `.github/` is included (GitHub tarballs strip `.git` only, not `.github`). The `Formula#install` block must explicitly NOT install `.github/` or other non-runtime dirs — Homebrew will only install what the `install` block copies.

---

## `brew audit` Feasibility in CI

[VERIFIED: local `brew audit --help` execution]

**Verdict: Feasible offline, but with caveats.**

`brew audit` accepts:
- `brew audit <formula-name>` — requires the formula to be in a tapped repository
- `brew audit --tap <user>/<repo>` — audits all formulas in a tapped repo
- `brew audit [path]` — **DISABLED** as of current Homebrew (returns error: "Calling `brew audit [path ...]` is disabled! Use `brew audit [name ...]` instead")

**CI feasibility options:**

1. **Tap the formula in CI then audit by name:** `brew tap mohandoz/conjure ./Formula && brew audit conjure` — works offline (no network needed for audit without `--online`). Requires brew on the runner (macOS runners have it; ubuntu runners need `linuxbrew` or skip this step).

2. **Ruby syntax check only:** `ruby -c Formula/conjure.rb` — validates Ruby parse without brew. Runs on any runner with ruby.

3. **Skip `brew audit` in CI:** Document BREW-01 as manual-only for the full install test. The formula syntax is validated by `ruby -c`; runtime correctness is validated by the CONJURE_HOME unit test.

**Recommendation:** Use `ruby -c Formula/conjure.rb` as the automated CI check (fast, zero-dependency). Document full `brew install` and `brew audit` as manual verification steps. The BREW-03 check (no HEAD/branch in formula) is a static grep in `tests/run.sh`, not a brew audit.

---

## CONJURE_HOME Unit Test Approach

[VERIFIED: 13-PATTERNS.md provides exact test code; CONTEXT.md confirms testability]

The BREW-02 test in `tests/run.sh` is a pure bash unit test — no brew installation required:

```bash
# BREW-02: CONJURE_HOME env var override unit test
BREW_FAKE="$(mktemp -d)"
trap 'rm -rf "$BREW_FAKE"' EXIT
printf '9.8.7\n' > "$BREW_FAKE/VERSION"
BREW_VER_OUT="$(CONJURE_HOME="$BREW_FAKE" cli/conjure version 2>&1)"
if printf '%s\n' "$BREW_VER_OUT" | grep -q '9.8.7'; then
  pass "CONJURE_HOME env var overrides default resolution (BREW-02)"
else
  fail "CONJURE_HOME env var did NOT override — got: $BREW_VER_OUT (BREW-02)"
fi
rm -rf "$BREW_FAKE"
trap - EXIT
```

**Why this works:** After D-03, `cli/conjure` line 24 becomes `CONJURE_HOME="${CONJURE_HOME:-...}"`. When `CONJURE_HOME=/tmp/fake` is set in the calling environment, the `${...:-...}` conditional short-circuits and `$CONJURE_HOME` is never recomputed. Line 25 then reads `$CONJURE_HOME/VERSION` from the fake dir, producing `9.8.7`.

**Prerequisite:** This test must run AFTER the D-03 one-line edit is applied to `cli/conjure`. If run against the current `cli/conjure` (hard-coded assignment), the test will always fail regardless of CONJURE_HOME.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SHA256 computation at release time | Custom shell script to fetch tarball and hash | bump-homebrew-formula-action | Action handles fetch + hash + commit/PR atomically; race conditions are handled |
| Wrapper script env injection | Custom Ruby helper | `(bin/"formula").write <<~SH ... SH` heredoc | Standard Homebrew idiom; produces correct permissions automatically |
| Formula path resolution in test | Custom brew invocation | `ruby -c Formula/conjure.rb` | Validates syntax without requiring brew; faster and portable |
| Tag tracking across repos | Custom webhook or cron | bump-homebrew-formula-action triggered by release event | Action fires synchronously after release; no polling needed |

**Key insight:** The Homebrew wrapper pattern exists precisely to avoid calling `brew --prefix` at runtime. Any solution that queries brew at invocation time adds 150-300ms latency and a hard dependency on brew being on PATH. The wrapper captures the path at install time via Ruby interpolation — zero runtime cost.

---

## Common Pitfalls

### Pitfall 1: `share.install` vs `(share/"conjure").install`

**What goes wrong:** Writing `share.install "cli", "scripts", ...` installs `cli/` as `share/cli/` (i.e., `$(brew --prefix)/share/cli/`), NOT `share/conjure/cli/`. The wrapper then references `#{share}/conjure/cli/conjure` which does not exist.

**Why it happens:** `share` is a `Pathname` object pointing to `prefix/share`. Calling `.install "cli"` on it moves the `cli/` directory directly into `share/`, not into a subdirectory named after the formula.

**How to avoid:** Use `(share/"conjure").install "cli", "scripts", ...` to install into `share/conjure/`. The `"conjure"` subdir is created automatically.

**Warning signs:** `brew install` succeeds but `conjure version` exits with "Failed to load lib/mutate.sh — check CONJURE_HOME" or similar. The wrapper's `CONJURE_HOME` path exists but is empty or missing subdirectories.

---

### Pitfall 2: `tap-repo` vs `homebrew-tap` input name

**What goes wrong:** The action input is named `homebrew-tap`, not `tap-repo`. Using `tap-repo:` in the `with:` block causes it to be silently ignored; the action then defaults `homebrew-tap` to `Homebrew/homebrew-core` and attempts to PR homebrew-core, which fails authorization.

**Why it happens:** The `13-PATTERNS.md` pre-existing in this repo uses `tap-repo:` in the example — this is incorrect. The verified `action.yml` uses `homebrew-tap:`.

**How to avoid:** Use `homebrew-tap: mohandoz/homebrew-conjure` in the workflow step.

**Warning signs:** Release workflow run shows "bumping Homebrew/homebrew-core" in action logs, or action fails with a permissions error against homebrew-core.

---

### Pitfall 3: Formula `install` block runs during `brew install`, not at tap time

**What goes wrong:** Assuming the formula's `test do` block runs during `brew install`. It does not — `test do` runs only when the user explicitly executes `brew test conjure`.

**Why it happens:** The distinction is often misunderstood. `brew install` runs `def install`. `brew test conjure` runs `test do`.

**How to avoid:** The `test do` block in `conjure.rb` should be minimal (`system bin/"conjure", "version"`). Document BREW-01 as requiring a manual `brew install` + `conjure --version` check; it cannot be automated in CI without a real brew installation.

---

### Pitfall 4: Tarball path prefix inside the archive

**What goes wrong:** GitHub-generated tarballs from `archive/refs/tags/v*.tar.gz` extract to a directory named `conjure-VERSION/` (e.g., `conjure-0.3.0/`). The formula's `def install` block runs with `Dir.chdir` already set to this extracted directory, so `share.install "cli"` finds `cli/` relative to that. No path prefix is needed.

**Why it happens:** Developers sometimes add explicit path prefixes thinking they need to navigate into the extracted dir.

**How to avoid:** Keep install paths relative (e.g., `"cli"`, `"scripts"`), not absolute. Homebrew handles the chdir.

---

### Pitfall 5: `HOMEBREW_TAP_GITHUB_TOKEN` scope

**What goes wrong:** Creating the PAT with only `repo` scope causes the bump action to fail when the tap repo's default branch has branch protection rules requiring signed commits or status checks.

**Why it happens:** `repo` scope covers content writes but not workflow file changes. If `.github/workflows/` files exist in the tap repo, `workflow` scope may be needed.

**How to avoid:** Create the PAT with both `repo` and `workflow` scopes. For a new tap repo with no branch protections, `repo` scope alone suffices. Set branch protections on the tap repo only after verifying the PAT works.

---

### Pitfall 6: `brew audit [path]` is disabled

**What goes wrong:** CI step runs `brew audit Formula/conjure.rb` and fails with "Calling `brew audit [path ...]` is disabled!"

**Why it happens:** Homebrew removed path-based audit in a recent version. Only name-based audit works.

**How to avoid:** Use `ruby -c Formula/conjure.rb` for syntax checking in CI. For full audit, tap locally first: `brew tap mohandoz/conjure ./ && brew audit conjure`.

---

## `mohandoz/homebrew-conjure` Tap Repo — What It Needs

[VERIFIED: docs.brew.sh/Taps + docs.brew.sh/How-to-Create-and-Maintain-a-Tap]

**Minimum required contents:**

```
homebrew-conjure/
└── Formula/
    └── conjure.rb
```

That is the absolute minimum. Homebrew searches for `Formula/`, `HomebrewFormula/`, or root-level `*.rb` files (in that priority order). The `Formula/` subdirectory is standard and recommended.

**Recommended contents:**

```
homebrew-conjure/
├── Formula/
│   └── conjure.rb          # The formula (kept in sync by bump action)
└── README.md               # Install instructions for users
```

**No other files are required.** No `Gemfile`, no `Brewfile`, no CI configuration in the tap repo itself. The bump action maintains the formula via direct push or PR — it does not need CI in the tap repo.

**Naming rule:** The GitHub repo MUST be named `homebrew-conjure` (with the `homebrew-` prefix). This allows `brew tap mohandoz/conjure` (without the `homebrew-` prefix). The full three-part install form `brew install mohandoz/conjure/conjure` auto-taps if not already tapped.

**Initial bootstrap:** The tap repo must be created manually before the first release. Create it on GitHub, add `Formula/conjure.rb` with a placeholder SHA256 (or the actual sha256 for v0.3.0 if tagging immediately). The bump action will update it on the next release.

---

## Code Examples

### Formula install block (correct idiom)

```ruby
# Source: Homebrew Formula Cookbook (docs.brew.sh/Formula-Cookbook)
# + Homebrew pathname.rb source (/opt/homebrew/Library/Homebrew/extend/pathname.rb)

def install
  (share/"conjure").install "cli", "scripts", "profiles", "compliance",
                             "migrations", "templates", "lib", "VERSION"

  (bin/"conjure").write <<~SH
    #!/bin/bash
    export CONJURE_HOME="#{share}/conjure"
    exec "#{share}/conjure/cli/conjure" "$@"
  SH
end
```

### Formula test block

```ruby
# Source: Homebrew Formula Cookbook
test do
  system bin/"conjure", "version"
end
```

### release.yml bump step (correct input names)

```yaml
# Source: action.yml fetched from github.com/mislav/bump-homebrew-formula-action
      - name: Bump Homebrew formula
        uses: mislav/bump-homebrew-formula-action@v3
        with:
          formula-name: conjure
          homebrew-tap: mohandoz/homebrew-conjure
          download-url: https://github.com/mohandoz/conjure/archive/refs/tags/${{ github.ref_name }}.tar.gz
        env:
          COMMITTER_TOKEN: ${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}
```

### D-03 one-line fix in `cli/conjure`

```bash
# Source: cli/conjure line 24 (current)
# BEFORE:
CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

# AFTER (D-03):
CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
```

### BREW-02 unit test in tests/run.sh

```bash
# Source: 13-PATTERNS.md pattern extraction
BREW_FAKE="$(mktemp -d)"
trap 'rm -rf "$BREW_FAKE"' EXIT
printf '9.8.7\n' > "$BREW_FAKE/VERSION"
BREW_VER_OUT="$(CONJURE_HOME="$BREW_FAKE" cli/conjure version 2>&1)"
if printf '%s\n' "$BREW_VER_OUT" | grep -q '9.8.7'; then
  pass "CONJURE_HOME env var overrides default resolution (BREW-02)"
else
  fail "CONJURE_HOME env var did NOT override — got: $BREW_VER_OUT (BREW-02)"
fi
rm -rf "$BREW_FAKE"
trap - EXIT
```

### BREW-03 static grep test

```bash
# Source: tests/run.sh lines 165-183 (template lint pattern)
if grep -qE '\bHEAD\b|\bbranch\b' "$CONJURE_HOME/Formula/conjure.rb" 2>/dev/null; then
  fail "Formula/conjure.rb contains HEAD or branch reference (BREW-03)"
else
  pass "Formula/conjure.rb: no HEAD or branch reference (BREW-03)"
fi
```

### BREW-04 static grep test

```bash
if grep -q 'bump-homebrew-formula-action' "$CONJURE_HOME/.github/workflows/release.yml" 2>/dev/null; then
  pass "release.yml references bump-homebrew-formula-action (BREW-04)"
else
  fail "release.yml missing bump-homebrew-formula-action reference (BREW-04)"
fi
```

### BREW-01 formula Ruby syntax check (automated CI alternative)

```bash
if ruby -c "$CONJURE_HOME/Formula/conjure.rb" >/dev/null 2>&1; then
  pass "Formula/conjure.rb: valid Ruby syntax (BREW-01)"
else
  fail "Formula/conjure.rb: Ruby syntax error (BREW-01)"
fi
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `brew audit [path]` | `brew audit [name]` only | Recent Homebrew (verified: disabled in 5.1.13) | Cannot lint formula by file path in CI; must tap first or use `ruby -c` |
| Node 20 in bump action | Node 24 in v4+ | bump-action v4.0 | v3 still uses Node 20; functional but eventually deprecated |
| Hard-coded CONJURE_HOME | Conditional `${:-}` | This phase (D-03) | Enables wrapper pattern without breaking existing installs |

**Deprecated/outdated:**
- `brew audit Formula/conjure.rb` (path form): disabled. Use `ruby -c` or tap-then-audit.
- `write_env_script` as primary pattern: still works but hand-written heredoc is clearer for single-variable case and avoids relying on internal Homebrew APIs.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Using `@v3` tag for bump action resolves to v3.6 | Standard Stack / Bump Step | If tag moves or is deleted, workflow breaks; mitigation: pin to SHA in Phase 15 |
| A2 | GitHub-generated tarball for `archive/refs/tags/v0.3.0.tar.gz` includes all files listed in D-06 (`cli/`, `scripts/`, etc.) | Files Installed vs Excluded | If repo has a `.gitattributes` export-ignore rule, some dirs may be excluded from tarball; verify with `curl -L <tarball_url> | tar tz` before first release |
| A3 | `mohandoz/homebrew-conjure` tap repo does not yet exist | Tap Repo section | If it exists with conflicting content, bootstrap step must merge carefully |

---

## Open Questions (RESOLVED)

1. **SHA256 placeholder in `Formula/conjure.rb`** (RESOLVED)
   - Resolution: Use `"PLACEHOLDER_SHA256_REPLACE_ON_FIRST_RELEASE"` in `Formula/conjure.rb` committed to this repo. The bump action updates the tap repo copy on first real release. Baked into Plan 13-01 Task 1.

2. **Tap repo creation step** (RESOLVED)
   - Resolution: Manual step documented in Plan 13-03 `user_setup` block and 13-VALIDATION.md Pre-release Checklist. One-time GitHub UI action; not automatable.

3. **`Formula/conjure.rb` version hardcoded vs templated** (RESOLVED)
   - Resolution: Formula in `Formula/conjure.rb` in this repo is a template with a placeholder SHA256. Tap repo copy (`mohandoz/homebrew-conjure`) is the live copy updated by the bump action. The copies deliberately diverge after first release. Documented in formula header comment.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| brew | Formula testing (manual) | Yes | 5.1.13 | — |
| ruby | `ruby -c` syntax check | Yes | 2.6.10 (system) | brew install ruby |
| GitHub Actions (ubuntu-latest) | release.yml bump step | Yes (CI) | runner-managed | — |
| `HOMEBREW_TAP_GITHUB_TOKEN` secret | bump action | Must be created manually | — | No fallback; required for BREW-04 |
| `mohandoz/homebrew-conjure` repo | bump action push target | Must be created manually | — | No fallback; required for BREW-04 |

**Missing dependencies with no fallback:**
- `HOMEBREW_TAP_GITHUB_TOKEN` secret — must be created in GitHub repo settings before first release
- `mohandoz/homebrew-conjure` repo — must be created on GitHub before first release

**Missing dependencies with fallback:**
- `ruby -c` for formula syntax check — if system ruby is too old, `brew install ruby` provides a current version

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Hand-rolled bash test runner |
| Config file | none |
| Quick run command | `bash tests/run.sh` |
| Full suite command | `bash tests/run.sh` |
| Estimated runtime | ~15 seconds |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BREW-01 | `Formula/conjure.rb` has valid Ruby syntax | unit (static) | `bash tests/run.sh` (ruby -c check) | ❌ Wave 0 |
| BREW-01 | `brew install mohandoz/conjure/conjure` succeeds | manual | manual — requires real brew + tap repo | N/A (manual) |
| BREW-01 | `conjure --version` exits 0 after brew install | manual | manual | N/A (manual) |
| BREW-02 | `CONJURE_HOME` env var overrides default resolution | unit | `bash tests/run.sh` (BREW_FAKE test) | ❌ Wave 0 |
| BREW-03 | Formula has no HEAD or branch reference | static grep | `bash tests/run.sh` | ❌ Wave 0 |
| BREW-04 | `release.yml` references bump-homebrew-formula-action | static grep | `bash tests/run.sh` | ❌ Wave 0 |

### Sampling Rate

- **After every task commit:** `bash tests/run.sh`
- **After every plan wave:** `bash tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite must be green

### Wave 0 Gaps

- [ ] BREW test block in `tests/run.sh` — covering all 4 automated assertions above
- [ ] `Formula/conjure.rb` — must exist for ruby -c test to pass
- [ ] `cli/conjure` D-03 edit — must be applied for BREW-02 test to pass

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | Formula is a static config file; no user input |
| V6 Cryptography | yes (adjacent) | SHA256 verification by Homebrew at install time |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Supply-chain: tarball substitution | Tampering | SHA256 pinning in formula + Homebrew verification at install |
| Supply-chain: bump action compromise | Tampering | `@v3` tag; Phase 15 will pin to SHA |
| Token leakage: HOMEBREW_TAP_GITHUB_TOKEN in logs | Info Disclosure | Never echo token; it is passed as env var to action, not as a shell arg |

---

## Sources

### Primary (HIGH confidence)

- Homebrew Formula Cookbook — `docs.brew.sh/Formula-Cookbook` — DSL patterns, install block, test block, directory variables
- Homebrew Pathname API — `/opt/homebrew/Library/Homebrew/extend/pathname.rb` (local file, read directly) — `write_env_script`, `write_exec_script`, `env_script_all_files` exact implementations
- `mislav/bump-homebrew-formula-action` action.yml — fetched from `github.com/mislav/bump-homebrew-formula-action/blob/main/action.yml` — all input names and defaults
- GitHub API tags — `api.github.com/repos/mislav/bump-homebrew-formula-action/tags` — confirmed v3.0 through v3.6 exist; v4.1 is latest overall
- Homebrew Taps documentation — `docs.brew.sh/Taps` + `docs.brew.sh/How-to-Create-and-Maintain-a-Tap` — tap repo structure requirements
- Local `brew audit --help` — confirms path-based audit is disabled; name-based audit requires tap
- Local `brew --version` — confirmed Homebrew 5.1.13 available on dev machine

### Secondary (MEDIUM confidence)

- Homebrew community discussion `github.com/orgs/Homebrew/discussions/5388` — real bash formula example (betterdiscordctl) confirming `bin.install "script_name"` pattern
- bump-homebrew-formula-action README — confirmed token name (`COMMITTER_TOKEN` env var), PR vs direct push behavior

### Tertiary (LOW confidence)

- None — all key claims verified via primary sources.

---

## Metadata

**Confidence breakdown:**
- Formula DSL: HIGH — verified against Homebrew source and Cookbook
- bump-homebrew-formula-action inputs: HIGH — read directly from action.yml
- Tap repo structure: HIGH — from official docs
- `brew audit` feasibility: HIGH — tested locally
- CONJURE_HOME unit test: HIGH — pattern from 13-PATTERNS.md, logic verified against cli/conjure source

**Research date:** 2026-05-26
**Valid until:** 2026-08-26 (Homebrew API stable; bump action v3 pinned; 90-day window)
