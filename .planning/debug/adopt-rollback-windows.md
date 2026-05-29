---
slug: adopt-rollback-windows
status: investigating
trigger: "conjure adopt --rollback aborts on native Windows Git Bash (windows-test CI). snapshot_rollback fails so scaffolded .claude files survive, no [ROLLBACK] log entry, post-rollback diff non-empty. 5 remaining CI failures (adopt rollback x3 + argus rollback x2). macOS/Linux green at 439/0."
created: 2026-05-29
updated: 2026-05-29
---

# Debug: adopt --rollback aborts on native Windows Git Bash

## Symptoms

- **Expected:** `conjure adopt --rollback <target>` restores the snapshot, deletes scaffolded `created[]` files, verifies sha256 of mutated files, logs a `[ROLLBACK]` entry, exits 0. Post-rollback `diff -r` (excl. conjure dirs) is empty. Works on macOS + Linux (suite 439/0).
- **Actual (native Windows Git Bash, CI job `windows-test` only):** rollback aborts. `.claude/hooks` scaffolded files survive, RESTRUCTURE-LOG.md has no `[ROLLBACK]` entry, post-rollback diff non-empty.
- **5 failing assertions:** adopt rollback (scaffolded-present, no-[ROLLBACK]-log, diff-not-empty `Only in .../.claude: COMPOUND-CANDIDATES.md`) + argus rollback (no-[ROLLBACK]-log, diff-not-empty `Only in <target>: .claude`).
- **Timeline:** Introduced by v0.6.0 (Phase 21-24, snapshot/adopt are new). Surfaced only on Windows CI — the milestone audit + local verification were macOS-only.
- **Repro:** Windows Git Bash CI `windows-test` job (`bash --noprofile --norc -e -o pipefail`). NOT reproducible on macOS/Linux. Each CI cycle ~21 min (windows-test is the long pole).

## Already fixed (11 Windows failures → 5)

- `snapshot_create` (lib/snapshot.sh): `cp -a` → `tar --exclude=.git --exclude=node_modules` (commit a1ff4ca).
- `snapshot_rollback` (lib/snapshot.sh): `cp -a snapshot/. target/` → `( cd snap && tar -cf - . ) | ( cd target && tar -xpf - )` with cp fallbacks (commit 112cb70). **DID NOT fix the rollback abort — still failing.**
- Perf gate: platform-aware `PERF_CEILING` (30s Unix / 240s Windows) — Git Bash fork overhead (112cb70).
- Symlink-skip tests: gate on `[ -L ]` (Windows git checks out symlinks as files) (112cb70).
- `mutate_archive` D-13 abort test: portable file-as-archive-root injection (chmod-555 ignored by Windows) (112cb70).
- `brownfield-simple` → `_brownfield-simple` (excluded from generic golden loops) (ef5642f).

## Key code

- `scripts/adopt.sh` `rollback_path()` (~280-368):
  - step1 `snapshot_rollback "$snap" "$TARGET"` (line ~307) → `exit 2` on non-zero (line ~311). NO [ROLLBACK] log if this aborts.
  - step2 created-delete loop `mutate_rm "$TARGET/$p"` (327-331) + empty-dir prune.
  - step3 sha256-verify mutated[] (350-360) → `exit 2` on mismatch.
  - `log_step ROLLBACK` (363) → only reached if steps 1-3 pass.
- `lib/snapshot.sh` `snapshot_rollback()` (~77-95): now tar -xpf, cp -a/-Rp fallback.
- Tests: `tests/run.sh:2569+` (adopt rollback, P22_RB_*), argus rollback (P24 criterion 2). Both invoke `CONJURE_ADOPT_ROLLBACK=1 bash adopt.sh --rollback`.

## Current Focus

hypothesis: snapshot_rollback still returns non-zero on Windows Git Bash even with tar — rollback_path aborts at step1 (line 311) before created-delete + [ROLLBACK] log. Candidate causes: (a) tar -xpf fails overwriting existing target files (read-only/locked/perm); (b) the `( cd ... ) | ( cd ... )` subshell pipe interacts badly with the snapshot path; (c) tar restoring `.conjure-adopt-state`/`.snapshot-meta.json` over live files; (d) abort is actually at step3 sha-verify (CRLF/line-ending mismatch between recorded before-hash and tar-restored bytes).
test: read the CI diagnostic — commit 74b655d added `[diag] adopt rollback rc=N out=...` capture; CI run 26649103286 (windows-test) is in-flight and will print the real snapshot_rollback/rollback_path stderr.
expecting: the diag reveals which step aborts + the exact error message, distinguishing (a)-(d).
next_action: read CI run 26649103286 windows-test log for `[diag]` + any `✗ adopt.sh: --rollback:` stderr; if not yet complete, poll until done; then pinpoint the failing step and fix.
reasoning_checkpoint: cannot reproduce locally (Windows-only); fixes must be reasoned from the diag + code, then validated via a CI push cycle (~21 min). Prefer a single targeted fix per cycle.

## Evidence

- timestamp 2026-05-29: macOS suite 439/0; Windows windows-test PASS 434 FAIL 5 (down from FAIL 11). Linux test job green.
- timestamp 2026-05-29: post-rollback `.claude/hooks` file count > 0 on Windows (assertion "scaffolded created[] files removed" fails) → step2 created-delete did NOT run → step1 snapshot_rollback aborted (rollback_path line 311) for the argus case (whole .claude survives). adopt case leaves only COMPOUND-CANDIDATES.md (ambiguous — may be a separate created[]-tracking gap or step3 abort).
- timestamp 2026-05-29: diagnostic commit 74b655d in-flight (run 26649103286) to capture the suppressed rollback stderr.

## Eliminated

- hypothesis: snapshot .git read-only objects cause the rollback cp failure — ELIMINATED: snapshot_create now excludes .git (a1ff4ca); rollback still fails without .git in the snapshot.
- hypothesis: cp -a ownership-preservation is the sole cause — PARTIALLY ELIMINATED: switched rollback to tar -xpf (112cb70), rollback still aborts.

## Resolution

(pending)
