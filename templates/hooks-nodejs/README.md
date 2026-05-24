# Cross-Platform Hooks (Node.js)

Bash hooks in `templates/hooks/` work on macOS/Linux/WSL2. For projects that
need to support **native Windows** developers, use these Node.js (`.mjs`)
equivalents instead.

## Why Node.js?

- Claude Code requires Node.js on every platform, so `node` is always available.
- `os.homedir()`, `os.tmpdir()`, `path.join()` handle OS differences automatically.
- No `bash` / `sh` / `cmd` / `powershell` dependency in `settings.json`.

## Three rules for universal hooks

1. **Never hardcode paths** — use `path.join(os.homedir(), '.foo')` not `~/.foo`.
2. **Never hardcode separators** — use `path.join()` not `/` or `\`.
3. **Never reference shell-specific env vars** — use `os.homedir()` not `$HOME` or `%USERPROFILE%`.

## Files

| Bash equivalent | Node.js version |
| --- | --- |
| `post-edit-format.sh` | `post-edit-format.mjs` |
| `pre-bash-block-destructive.sh` | `pre-bash-block-destructive.mjs` |
| `pre-commit-quality-gate.sh` | `pre-commit-quality-gate.mjs` |
| `stop-compound-engineering.sh` | `stop-compound-engineering.mjs` |
| `session-start-context.sh` | `session-start-context.mjs` |

## How to install

Copy the `.mjs` files instead of `.sh` files into `.claude/hooks/`. Update
`settings.json` to invoke `node` instead of `bash`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{
          "type": "command",
          "command": "node .claude/hooks/post-edit-format.mjs"
        }]
      }
    ]
  }
}
```

## Exit codes (same as bash)

- `process.exit(0)` — allow
- `process.exit(2)` — block (PreToolUse) or warn (others). NEVER use `exit(1)` for policy.
