---
plan: 13-01
phase: 13-homebrew-tap
status: complete
started: 2026-05-26
completed: 2026-05-26
commit: ab29409
requirements-satisfied:
  - BREW-01
  - BREW-02
  - BREW-03
key-files:
  created:
    - Formula/conjure.rb
  modified:
    - cli/conjure
deviations: none
self-check: PASSED
---

## Summary

Created `Formula/conjure.rb` — the Homebrew formula template for the
`mohandoz/conjure` tap — and applied the one-line D-03 CONJURE_HOME conditional
to `cli/conjure`.

## What Was Built

**Formula/conjure.rb** (new):
- Class `Conjure` with desc, homepage, tagged tarball url (v0.3.0), sha256
  placeholder, MIT license
- Install block uses `(share/"conjure").install` (not `share.install`) so all
  runtime dirs land at `share/conjure/` — wrapper path is correct
- Bin wrapper heredoc exports `CONJURE_HOME="#{share}/conjure"` and execs
  `share/conjure/cli/conjure` — hardcoded Cellar path, no `brew --prefix`
  at runtime
- `test do` block calls `bin/"conjure", "version"`
- `ruby -c` passes; no HEAD or branch reference in url field

**cli/conjure line 24** (one-character change):
- Before: `CONJURE_HOME="$(cd "$(dirname "$0")/.." && pwd)"`
- After: `CONJURE_HOME="${CONJURE_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"`
- When CONJURE_HOME is set (Homebrew wrapper), subshell never runs
- When not set (dev checkout), behavior identical to before
- shellcheck: no new warnings from this change

## Verification

1. `ruby -c Formula/conjure.rb` → Syntax OK
2. `grep '(share/"conjure").install' Formula/conjure.rb` → matches
3. `grep -E '\bHEAD\b|\bbranch\b' Formula/conjure.rb` → no matches (BREW-03)
4. Line 24 is conditional form — `grep -c "CONJURE_HOME=\${" cli/conjure` → 1
5. `shellcheck cli/conjure` → no new warnings (pre-existing warnings unchanged)
6. `grep 'exec.*share.*conjure/cli/conjure' Formula/conjure.rb` → matches

## Deviations

None. All tasks executed as specified.
