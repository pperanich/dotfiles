#!/bin/bash
# Reassign all windows to their configured workspaces based on app-bundle-id
# Mirrors the [[on-window-detected]] rules in aerospace.toml

aerospace=/opt/homebrew/bin/aerospace

# Map app-bundle-id to workspace
get_workspace() {
  case "$1" in
  org.alacritty | com.mitchellh.ghostty)
    echo 1
    ;; # term
  com.apple.Safari | com.brave.Browser)
    echo 2
    ;; # web
  md.obsidian | com.apple.Notes)
    echo 3
    ;; # notes
  com.microsoft.VSCode)
    echo 4
    ;; # ide
  com.tinyspeck.slackmacgap | com.microsoft.Outlook | us.zoom.xos)
    echo 5
    ;; # comms
  org.gimp.gimp-2.10 | org.blender.blender | com.cockos.reaper)
    echo 6
    ;; # creative
  com.apple.MobileSMS | com.hnc.Discord | im.riot.app)
    echo 7
    ;; # social
  *)
    echo ""
    ;; # no assignment
  esac
}

# Process all windows in a single pass
$aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}' | while IFS='|' read -r window_id bundle_id; do
  workspace=$(get_workspace "$bundle_id")
  if [[ -n $workspace ]]; then
    $aerospace move-node-to-workspace --window-id "$window_id" "$workspace" 2>/dev/null
  fi
done

# Trigger sketchybar update
sketchybar --trigger aerospace_window_move
