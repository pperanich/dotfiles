#!/bin/bash
# Reassign all workspaces to their configured monitors
# Mirrors the workspace-to-monitor-force-assignment config

aerospace=/opt/homebrew/bin/aerospace

# Primary workspaces -> main display
$aerospace move-workspace-to-monitor --workspace 1 main built-in
$aerospace move-workspace-to-monitor --workspace 4 main built-in
$aerospace move-workspace-to-monitor --workspace 5 main built-in

# Secondary workspaces -> external display (with fallbacks)
$aerospace move-workspace-to-monitor --workspace 2 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 3 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 6 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 7 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 8 secondary main built-in

# Trigger sketchybar update with current focused workspace
focused=$($aerospace list-workspaces --focused)
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$focused"
