#!/data/data/com.termux/files/usr/bin/bash
# phone-clean.sh — Junk cleaner for Android via Termux
# Works within scoped-storage limits (no root needed).
# Usage: bash phone-clean.sh [--dry-run] [--yes]

set -uo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SD="/sdcard"
TERMUX_HOME="$HOME"
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

hr()  { printf '%0.s─' $(seq 1 50); echo; }
log() { echo -e "${CYAN}▶${RESET} $*"; }
ok()  { echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}✘${RESET} $*"; }

human_size() {
  local b=${1:-0}
  if   [ "$b" -ge $((1024*1024*1024)) ]; then printf "%.1f GB" "$(echo "scale=1; $b/1073741824" | bc 2>/dev/null || echo '?')"
  elif [ "$b" -ge $((1024*1024))      ]; then printf "%.1f MB" "$(echo "scale=1; $b/1048576"    | bc 2>/dev/null || echo '?')"
  elif [ "$b" -ge 1024                ]; then printf "%.1f KB" "$(echo "scale=1; $b/1024"        | bc 2>/dev/null || echo '?')"
  else printf "%d B" "$b"; fi
}

disk_free_bytes() {
  df -k "$SD" 2>/dev/null | awk 'NR==2 {print $4 * 1024}' || echo 0
}

file_size() {
  # stat is not available on all Termux builds; fall back to wc
  stat -c%s "$1" 2>/dev/null || wc -c < "$1" 2>/dev/null || echo 0
}

dir_size() {
  du -sb "$1" 2>/dev/null | awk '{print $1}' || echo 0
}

# ── Accumulators ──────────────────────────────────────────────────────────────
declare -a TARGETS=()
TOTAL_BYTES=0

collect() {
  local label="$1"; shift
  local count=0 bytes=0

  while IFS= read -r -d '' path; do
    local size=0
    if [ -d "$path" ]; then size=$(dir_size "$path")
    else size=$(file_size "$path"); fi
    TARGETS+=("$path")
    bytes=$((bytes + size))
    TOTAL_BYTES=$((TOTAL_BYTES + size))
    count=$((count + 1))
  done < <(find "$@" -print0 2>/dev/null)

  [ "$count" -gt 0 ] && \
    printf "  %-34s %4d items   %s\n" "$label" "$count" "$(human_size $bytes)"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}  Phone Cleaner — Termux${RESET}"
hr

if [ ! -d "$SD" ]; then
  err "Storage not mounted. Run:  termux-setup-storage"
  err "Grant permission, restart Termux, then try again."
  exit 1
fi

$DRY_RUN && warn "DRY RUN — nothing will be deleted"
FREE_BEFORE=$(disk_free_bytes)
log "Free before : $(human_size "$FREE_BEFORE")"
echo

# ── What Termux CAN actually access on modern Android ─────────────────────────
# Android 10+ blocks Android/data/* — we focus on user-accessible paths.

log "Scanning accessible storage..."
hr

# 1. Thumbnail cache (readable on most devices)
for thumb_dir in \
    "$SD/DCIM/.thumbnails" \
    "$SD/Pictures/.thumbnails" \
    "$SD/.thumbnails"; do
  [ -d "$thumb_dir" ] && \
    collect "Thumbnails ($thumb_dir)" \
      "$thumb_dir" -type f
done

# 2. Temp / backup files anywhere under /sdcard
collect "Temp & backup files" \
  "$SD" -type f \( \
    -iname "*.tmp"  -o -iname "*.temp" -o \
    -iname "*.bak"  -o -iname "*.old"  -o \
    -iname "*.orig" \
  \)

# 3. Log / crash files
collect "Log & crash files" \
  "$SD" -type f \( \
    -iname "*.log"   -o -iname "*.trace" -o \
    -iname "*.crash" -o -iname "*.dmp"   -o \
    -iname "*.hprof" \
  \)

# 4. Stale APKs in Downloads (already-installed packages)
collect "APKs in Downloads" \
  "$SD/Download" -maxdepth 2 -type f -iname "*.apk"

# 5. Empty directories under /sdcard (skip Android/ subtree — unreadable)
collect "Empty folders" \
  "$SD" \
    -mindepth 1 \
    -not -path "$SD/Android*" \
    -type d -empty

# 6. Termux package cache (always accessible)
TERMUX_PKG_CACHE="$TERMUX_HOME/../usr/var/cache/apt/archives"
if [ -d "$TERMUX_PKG_CACHE" ]; then
  collect "Termux pkg cache (.deb)" \
    "$TERMUX_PKG_CACHE" -maxdepth 1 -type f -name "*.deb"
fi

# 7. Termux home junk (~/.cache, pip cache, npm cache, etc.)
for cache_dir in \
    "$TERMUX_HOME/.cache" \
    "$TERMUX_HOME/.npm/_cacache" \
    "$TERMUX_HOME/.gradle/caches" \
    "$TERMUX_HOME/.cargo/registry/cache"; do
  [ -d "$cache_dir" ] && \
    collect "Termux cache ($cache_dir)" "$cache_dir" -mindepth 1 -maxdepth 1
done

hr

# ── Nothing found ─────────────────────────────────────────────────────────────
if [ "${#TARGETS[@]}" -eq 0 ]; then
  ok "Nothing accessible to clean."
  echo
  echo -e "  ${YELLOW}Note:${RESET} App caches in Android/data/ are blocked by Android 10+"
  echo    "  scoped-storage policy. To clean those you need either:"
  echo    "    • A rooted device"
  echo    "    • The app's own 'Clear Cache' button (Settings → Apps)"
  echo    "    • Settings → Storage → Cached Data → Clear"
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
echo; log "Cleaning..."
DELETED=0; FAILED=0; FREED=0

# Sort by path length descending (deepest first) so empty-dir parents work
IFS=$'\n' sorted=($(printf '%s\n' "${TARGETS[@]}" | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-))
unset IFS

for path in "${sorted[@]}"; do
  [ -e "$path" ] || continue  # already gone when parent was deleted

  if $DRY_RUN; then
    ok "[dry] $path"; DELETED=$((DELETED+1)); continue
  fi

  if [ -d "$path" ]; then size=$(dir_size "$path")
  else size=$(file_size "$path"); fi

  if rm -rf "$path" 2>/dev/null; then
    FREED=$((FREED+size)); DELETED=$((DELETED+1))
  else
    warn "Skipped: $path"; FAILED=$((FAILED+1))
  fi
done

# Also run Termux apt cache clean (no files to track, just run it)
if ! $DRY_RUN && command -v apt-get &>/dev/null; then
  apt-get clean -y &>/dev/null && ok "Termux apt cache cleared"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo; hr
ok "Removed  : $DELETED item(s)"
[ "$FAILED" -gt 0 ] && warn "Skipped  : $FAILED (permission denied)"
if ! $DRY_RUN; then
  ok "Freed    : $(human_size "$FREED")"
  ok "Free now : $(human_size "$(disk_free_bytes)")"
fi
hr; echo

if ! $DRY_RUN; then
  echo -e "  ${YELLOW}Tip:${RESET} For app caches blocked by Android scoped storage, go to:"
  echo    "  Settings → Storage → Free Up Space  (or Cached Data → Clear)"
fi
echo
