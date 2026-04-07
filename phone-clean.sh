#!/data/data/com.termux/files/usr/bin/bash
# phone-clean.sh — Junk cleaner for Android via Termux
# Usage: bash phone-clean.sh [--dry-run] [--yes]

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
STORAGE_ROOT="/sdcard"
DRY_RUN=false
AUTO_YES=false

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --yes|-y)  AUTO_YES=true ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
hr()  { printf '%0.s─' $(seq 1 50); echo; }
log() { echo -e "${CYAN}▶${RESET} $*"; }
ok()  { echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}✘${RESET} $*"; }

human_size() {
  # Accepts bytes, prints human-readable
  local b=$1
  if   [ "$b" -ge $((1024*1024*1024)) ]; then printf "%.1f GB" "$(echo "scale=1; $b/1073741824" | bc)"
  elif [ "$b" -ge $((1024*1024))      ]; then printf "%.1f MB" "$(echo "scale=1; $b/1048576"    | bc)"
  elif [ "$b" -ge 1024                ]; then printf "%.1f KB" "$(echo "scale=1; $b/1024"        | bc)"
  else printf "%d B" "$b"
  fi
}

disk_free_bytes() {
  df -k "$STORAGE_ROOT" 2>/dev/null | awk 'NR==2 {print $4 * 1024}' || echo 0
}

# Accumulator for what will be removed
declare -a TARGETS=()
TOTAL_BYTES=0

# Scan a directory tree and collect matching files/dirs
collect() {
  local label="$1"; shift
  local -a find_args=("$@")
  local count=0 bytes=0

  while IFS= read -r -d '' path; do
    local size
    size=$(du -sb "$path" 2>/dev/null | awk '{print $1}') || size=0
    TARGETS+=("$path")
    bytes=$((bytes + size))
    TOTAL_BYTES=$((TOTAL_BYTES + size))
    count=$((count + 1))
  done < <(find "${find_args[@]}" -print0 2>/dev/null)

  if [ "$count" -gt 0 ]; then
    printf "  %-30s %5d items   %s\n" "$label" "$count" "$(human_size $bytes)"
  fi
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}  Phone Cleaner — Termux${RESET}"
hr

if [ ! -d "$STORAGE_ROOT" ]; then
  err "Storage not accessible. Run: termux-setup-storage"
  err "Then restart Termux and try again."
  exit 1
fi

$DRY_RUN && warn "DRY RUN — nothing will be deleted"

FREE_BEFORE=$(disk_free_bytes)
log "Storage free before: $(human_size "$FREE_BEFORE")"
echo

# ── Scan ──────────────────────────────────────────────────────────────────────
log "Scanning for junk files..."
hr

# App cache directories  (Android/data/<pkg>/cache)
collect "App caches" \
  "$STORAGE_ROOT/Android/data" -mindepth 2 -maxdepth 2 \
  -type d -name "cache"

# Thumbnail caches
collect "Thumbnail caches" \
  "$STORAGE_ROOT" -maxdepth 3 \
  -type d \( -name ".thumbnails" -o -name "thumbnails" \)

# Temp / backup files
collect "Temp & backup files" \
  "$STORAGE_ROOT" \
  -type f \( \
    -iname "*.tmp"  -o -iname "*.temp" -o \
    -iname "*.bak"  -o -iname "*.old"  -o \
    -iname "*.orig" \
  \)

# Log & crash files
collect "Log & crash files" \
  "$STORAGE_ROOT" \
  -type f \( \
    -iname "*.log"   -o -iname "*.trace" -o \
    -iname "*.crash" -o -iname "*.dmp"   -o \
    -iname "*.hprof" \
  \)

# Empty directories (skip Android/data itself)
collect "Empty folders" \
  "$STORAGE_ROOT" \
  -mindepth 1 -not -path "$STORAGE_ROOT/Android/data" \
  -type d -empty

hr

if [ "${#TARGETS[@]}" -eq 0 ]; then
  ok "Nothing to clean — your phone is already tidy!"
  exit 0
fi

echo -e "  ${BOLD}Total: ${#TARGETS[@]} items — $(human_size "$TOTAL_BYTES") to free${RESET}"
echo

# ── Confirm ───────────────────────────────────────────────────────────────────
if ! $DRY_RUN && ! $AUTO_YES; then
  echo -ne "${YELLOW}Delete all of the above? [y/N] ${RESET}"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 0; }
fi

# ── Delete ────────────────────────────────────────────────────────────────────
echo
log "Cleaning..."
DELETED=0; FAILED=0; FREED=0

for path in "${TARGETS[@]}"; do
  [ -e "$path" ] || continue   # already gone (parent dir deleted earlier)

  if $DRY_RUN; then
    ok "[dry-run] $path"
    DELETED=$((DELETED + 1))
    continue
  fi

  size=$(du -sb "$path" 2>/dev/null | awk '{print $1}') || size=0

  if rm -rf "$path" 2>/dev/null; then
    FREED=$((FREED + size))
    DELETED=$((DELETED + 1))
  else
    warn "Skipped (permission denied): $path"
    FAILED=$((FAILED + 1))
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo
hr
FREE_AFTER=$(disk_free_bytes)
ACTUALLY_FREED=$((FREE_AFTER - FREE_BEFORE))

ok "Removed : $DELETED item(s)"
[ "$FAILED" -gt 0 ] && warn "Skipped  : $FAILED item(s) (permission denied)"
if ! $DRY_RUN; then
  ok "Freed    : $(human_size "$FREED")"
  ok "Free now : $(human_size "$FREE_AFTER")"
fi
hr
echo
