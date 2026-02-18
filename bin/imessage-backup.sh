#!/usr/bin/env bash
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
NAS_HOST="pp-nas1"
NAS_BACKUP_DIR="/tank/backups/imessage"
LOCAL_EXPORT_BASE="/tmp/imessage_export"

# ── Resolve iPhone backup path ──────────────────────────────────────
BACKUP_BASE="$HOME/Library/Application Support/MobileSync/Backup"

usage() {
  echo "Usage: $(basename "$0") <name> [backup-path]" >&2
  echo >&2
  echo "  name         Profile name (e.g. patrick, sarah)" >&2
  echo "  backup-path  Optional path to iPhone backup directory" >&2
  exit 1
}

backup_label() {
  local dir="$1"
  local plist="${dir%/}/Info.plist"
  if [[ -f $plist ]]; then
    local device product
    device=$(/usr/libexec/PlistBuddy -c "Print :Device\ Name" "$plist" 2>/dev/null) || device="Unknown"
    product=$(/usr/libexec/PlistBuddy -c "Print :Product\ Name" "$plist" 2>/dev/null) || product=""
    if [[ -n $product ]]; then
      echo "$device ($product)"
    else
      echo "$device"
    fi
  else
    basename "$dir"
  fi
}

find_backup() {
  local backups
  backups=$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null) || true

  if [[ -z $backups ]]; then
    echo "ERROR: No iPhone backups found in $BACKUP_BASE" >&2
    echo "Connect your iPhone and create a backup via Finder first." >&2
    exit 1
  fi

  local count
  count=$(echo "$backups" | wc -l | tr -d ' ')

  if [[ $count -eq 1 ]]; then
    local single
    single=$(echo "$backups" | head -1)
    echo "Found backup: $(backup_label "$single")" >&2
    echo "$single"
  else
    echo "Multiple backups found:" >&2
    local i=1
    while IFS= read -r dir; do
      echo "  $i) $(backup_label "$dir")" >&2
      ((i++))
    done <<<"$backups"
    echo >&2
    read -rp "Select backup number [1]: " choice
    choice="${choice:-1}"
    echo "$backups" | sed -n "${choice}p"
  fi
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  if [[ $# -lt 1 ]]; then
    usage
  fi

  local profile="$1"
  local snapshot_dir="${NAS_BACKUP_DIR}/${profile}/snapshots"
  local backup_path today local_export latest start_date

  if [[ -n ${2:-} ]]; then
    backup_path="$2"
  else
    backup_path=$(find_backup)
  fi
  backup_path="${backup_path%/}"

  if [[ ! -d $backup_path ]]; then
    echo "ERROR: Backup path does not exist: $backup_path" >&2
    exit 1
  fi
  echo "Profile: $profile"
  echo "Using backup: $backup_path"

  local password=""
  if [[ -f "${backup_path}/Manifest.plist" ]] &&
    /usr/libexec/PlistBuddy -c "Print :IsEncrypted" "${backup_path}/Manifest.plist" 2>/dev/null | grep -q true; then
    read -rsp "Backup is encrypted. Enter password: " password
    echo >&2
  fi

  today=$(date +%Y-%m-%d)
  local_export="${LOCAL_EXPORT_BASE}_${profile}_${today}"

  # Ensure clean local export dir (tool refuses if files exist)
  rm -rf "$local_export"
  mkdir -p "$local_export"

  # Find most recent snapshot on NAS
  echo "Checking NAS for previous snapshots..."
  latest=$(ssh "$NAS_HOST" \
    "ls -1d ${snapshot_dir}/????-??-?? 2>/dev/null | sort | tail -1 | xargs -r basename" \
    2>/dev/null) || true

  # Build export command
  local cmd=(
    imessage-exporter
    -f html
    -c full
    -i
    -p "$backup_path"
    -o "$local_export"
  )

  if [[ -n $password ]]; then
    cmd+=(-x "$password")
  fi

  if [[ -n $latest ]]; then
    # Start from day after last snapshot to avoid overlap
    start_date=$(date -j -v+1d -f "%Y-%m-%d" "$latest" "+%Y-%m-%d" 2>/dev/null) ||
      start_date="$latest"

    if [[ $start_date > $today || $start_date == "$today" ]]; then
      echo "Already up to date (last snapshot: $latest)"
      rm -rf "$local_export"
      exit 0
    fi

    echo "Incremental export from $start_date (last snapshot: $latest)"
    cmd+=(-s "$start_date")
  else
    echo "No previous snapshots — full export"
  fi

  # Skip export if a previous run's output still exists
  if [[ -n "$(ls -A "$local_export" 2>/dev/null)" ]]; then
    echo "Reusing existing export at $local_export"
  else
    echo "Exporting messages..."
    "${cmd[@]}"
  fi

  if [[ -z "$(ls -A "$local_export" 2>/dev/null)" ]]; then
    echo "No new messages to export."
    rm -rf "$local_export"
    exit 0
  fi

  ssh "$NAS_HOST" "mkdir -p ${snapshot_dir}/${today}"

  echo "Syncing to ${NAS_HOST}:${snapshot_dir}/${today}/..."
  rsync -avz "$local_export/" "${NAS_HOST}:${snapshot_dir}/${today}/"

  rm -rf "$local_export"

  echo "Done. Snapshot saved: ${snapshot_dir}/${today}"
}

main "$@"
