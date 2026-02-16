#!/bin/bash
# Reassign all workspaces to their configured monitors
# Mirrors the workspace-to-monitor-force-assignment config
# 1: term, 2: web, 3: notes, 4: ide, 5: comms, 6: creative, 7: social, 8: office

aerospace=/opt/homebrew/bin/aerospace

# Primary workspaces -> main display (term, ide, comms)
$aerospace move-workspace-to-monitor --workspace 1 main built-in
$aerospace move-workspace-to-monitor --workspace 4 main built-in
$aerospace move-workspace-to-monitor --workspace 5 main built-in

# Secondary workspaces -> external display (web, notes, creative, social, flex)
$aerospace move-workspace-to-monitor --workspace 2 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 3 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 6 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 7 secondary main built-in
$aerospace move-workspace-to-monitor --workspace 8 secondary main built-in

# Trigger sketchybar update with current focused workspace
focused=$($aerospace list-workspaces --focused)
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$focused"
