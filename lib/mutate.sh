#!/usr/bin/env bash
# lib/mutate.sh — sourced mutation chokepoint for Conjure.
# Source this file; call mutate_mkdir, mutate_cp, mutate_write, mutate_rm, mutate_archive, mutate_summary.
# Requires: DRY_RUN env var (0=live, 1=dry); set -u safe via ${DRY_RUN:-0}.
# POSIX bash 3.2+ compatible. No associative arrays, no mapfile, no local -n.
#
# Usage from any script:
#   source "$CONJURE_HOME/lib/mutate.sh"
#   mutate_mkdir   <dir>
#   mutate_cp      <src> <dest>
#   mutate_write   <dest> <content> [--append]
#   mutate_rm      <path>
#   mutate_archive <src_abs> <archive_root>
#   mutate_summary   # call at end of each script

# Initialize dry-run mutation counter if not already set.
# Safe under set -u; idempotent on re-source.
CONJURE_DRY_MUTATION_COUNT="${CONJURE_DRY_MUTATION_COUNT:-0}"

# mutate_mkdir <dir>
# In dry-run: prints [dry-run] would mkdir <dir>, increments counter.
# In live mode: runs mkdir -p.
mutate_mkdir() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would mkdir $1"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  mkdir -p "$1"
}

# mutate_cp <src> <dest>
# In dry-run: prints [dry-run] would cp <src> <dest>, increments counter.
# In live mode: uses cp -r for directories, plain cp for files.
mutate_cp() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would cp $1 $2"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  if [ -d "$1" ]; then
    cp -r "$1" "$2"
  else
    cp "$1" "$2"
  fi
}

# mutate_write <dest> <content> [--append]
# In dry-run: prints [dry-run] would write <dest>, increments counter.
# In live mode: writes or appends content using printf (portable, no echo -e/-n quirks).
# Pass content as a string arg — never pipe (pipe = subshell = lost counter).
mutate_write() {
  local dest="$1"
  local content="$2"
  local mode="${3:-}"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would write $dest"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  if [ "$mode" = "--append" ]; then
    printf '%s' "$content" >> "$dest"
  else
    printf '%s' "$content" > "$dest"
  fi
}

# mutate_rm <path>
# In dry-run: prints [dry-run] would rm <path>, increments counter.
# In live mode: removes the file with rm -f (no -r; callers control recursive logic).
mutate_rm() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would rm $1"
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  rm -f "$1"
}

# mutate_archive <src_abs> <archive_root>
# Moves src to archive_root preserving path structure (D-12). Never deletes without verify (D-13).
# In dry-run: prints [dry-run] would archive, increments counter, returns 0.
# In live mode: cp -a → sha256 verify → rm → ledger entry → counter increment.
# Aborts and returns 1 if sha256 mismatch; removes partial dest copy on mismatch.
mutate_archive() {
  local src="$1"
  local archive_root="$2"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] would archive ${src} → ${archive_root}/..."
    CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
    return 0
  fi
  # D-13 safety: src must be absolute and free of '..' traversal segments before
  # it is mirrored into archive_root. Without this, a relative or '..'-bearing src
  # produces a dest outside archive_root, defeating archive-preservation.
  case "${src}" in
    /*) ;;
    *) echo "[mutate_archive] ABORT: src must be an absolute path: ${src}" >&2; return 1 ;;
  esac
  case "/${src}/" in
    */../*) echo "[mutate_archive] ABORT: src contains traversal segment '..': ${src}" >&2; return 1 ;;
  esac
  # Derive mirror path (D-12): strip leading slash for path-preserving layout
  local rel="${src#/}"
  local dest="${archive_root}/${rel}"
  mkdir -p "$(dirname "${dest}")"
  if ! cp -a "${src}" "${dest}"; then
    echo "[mutate_archive] ABORT: cp failed for ${src}" >&2
    return 1
  fi
  # Cross-platform sha256 (Pitfall 4): sha256sum (Linux) or shasum (macOS)
  local src_hash dest_hash
  if command -v sha256sum >/dev/null 2>&1; then
    src_hash="$(sha256sum "${src}" | cut -d' ' -f1)"
    dest_hash="$(sha256sum "${dest}" | cut -d' ' -f1)"
  elif command -v shasum >/dev/null 2>&1; then
    src_hash="$(shasum -a 256 "${src}" | cut -d' ' -f1)"
    dest_hash="$(shasum -a 256 "${dest}" | cut -d' ' -f1)"
  else
    echo "[mutate_archive] ABORT: no sha256 tool available (sha256sum/shasum) — cannot verify copy" >&2
    rm -f "${dest}"
    return 1
  fi
  # D-13: never unlink unverified content
  if [ "${src_hash}" != "${dest_hash}" ]; then
    echo "[mutate_archive] ABORT: sha256 mismatch for ${src} — original preserved" >&2
    rm -f "${dest}"
    return 1
  fi
  rm -f "${src}"
  # Append ledger entry (D-13)
  printf '%s\t%s\t%s\t%s\n' \
    "${src}" "${dest}" "${src_hash}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    >> "${archive_root}/.archive-ledger"
  CONJURE_DRY_MUTATION_COUNT=$((CONJURE_DRY_MUTATION_COUNT + 1))
}

# mutate_summary
# Prints a summary line when DRY_RUN=1 or when any mutations were suppressed.
# Call at the end of each script that sources this library.
# Checking the counter (> 0) handles the case where DRY_RUN was set only as a
# per-command prefix for individual mutate_* calls rather than exported persistently.
mutate_summary() {
  if [ "${DRY_RUN:-0}" = "1" ] || [ "${CONJURE_DRY_MUTATION_COUNT:-0}" -gt 0 ]; then
    echo "[dry-run] ${CONJURE_DRY_MUTATION_COUNT} mutations skipped — run without --dry-run to apply"
  fi
}
