#!/bin/bash
# Reset all workspaces to their configured layouts
# tiles: 1 (term), 2 (web), 4 (ide)
# accordion: 3 (notes), 5 (comms), 6 (creative), 7 (social), 8 (office)

aerospace=/opt/homebrew/bin/aerospace

# Save current workspace
current=$($aerospace list-workspaces --focused)

# Apply tiles layout
for ws in 1 2 4; do
  $aerospace workspace "$ws"
  $aerospace layout tiles
done

# Apply accordion layout
for ws in 3 5 6 7 8; do
  $aerospace workspace "$ws"
  $aerospace layout accordion
done

# Return to original workspace
$aerospace workspace "$current"
