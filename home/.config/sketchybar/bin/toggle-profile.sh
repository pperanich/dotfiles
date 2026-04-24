#!/usr/bin/env bash
# Toggle sketchybar + aerospace between "pill" and "i3" profiles.
# Usage: toggle-profile.sh [pill|i3]   (no arg = flip current)

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar"
state_file="$state_dir/profile"
mkdir -p "$state_dir"

current="i3"
[[ -f $state_file ]] && current=$(<"$state_file")

if [[ $# -ge 1 ]]; then
  target="$1"
else
  target="i3"
  [[ $current == "i3" ]] && target="pill"
fi

case "$target" in
pill | i3) ;;
*)
  echo "toggle-profile: unknown profile '$target' (pill|i3)" >&2
  exit 1
  ;;
esac

aero="$HOME/.config/aerospace/aerospace.toml"
frag="$HOME/.config/aerospace/gaps.${target}.toml"

[[ -f $frag ]] || {
  echo "toggle-profile: missing $frag" >&2
  exit 1
}
[[ -f $aero ]] || {
  echo "toggle-profile: missing $aero" >&2
  exit 1
}

tmp=$(mktemp)
awk -v repl_file="$frag" '
  /^# >>> MANAGED_GAPS/ {
    print
    seen_start = 1
    while ((getline line < repl_file) > 0) print line
    close(repl_file)
    in_block = 1
    next
  }
  /^# <<< MANAGED_GAPS/ {
    in_block = 0
    seen_end = 1
    print
    next
  }
  !in_block { print }
  END {
    if (!seen_start || !seen_end) {
      print "toggle-profile: MANAGED_GAPS markers not found in aerospace.toml" > "/dev/stderr"
      exit 1
    }
  }
' "$aero" >"$tmp"

mv "$tmp" "$aero"
echo "$target" >"$state_file"

# macOS menu bar: pill = always hide, i3 = never hide
# AppleScript applies immediately (no logout). `defaults write` needs logout on Sequoia.
case "$target" in
pill) hide=true ;;
i3) hide=false ;;
esac
osascript -e "tell application \"System Events\" to tell dock preferences to set autohide menu bar to ${hide}" 2>/dev/null ||
  echo "toggle-profile: menu bar toggle failed (grant osascript Automation access in System Settings > Privacy)" >&2

sketchybar --reload
/opt/homebrew/bin/aerospace reload-config

echo "profile: $target"
