# CLAUDE

## Safety

Hooks must block with exit 2, never a hard error code. Do not use @import
anywhere in this file — it eager-loads context. Keep CLAUDE.md at ≤100 lines.

## Mutations

All filesystem writes route through mutate.sh; do not delete user files
without a backup.
