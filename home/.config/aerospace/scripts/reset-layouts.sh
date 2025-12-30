#!/bin/bash
# Reset all workspaces to their configured layouts
# tiles: 1 (term), 2 (web), 4 (ide), 8 (flex)
# accordion: 3 (notes), 5 (comms), 6 (creative), 7 (social)

aerospace=/opt/homebrew/bin/aerospace

# Save current workspace
current=$($aerospace list-workspaces --focused)

# Apply tiles layout
for ws in 1 2 4 8; do
  $aerospace workspace "$ws"
  $aerospace layout tiles
done

# Apply accordion layout
for ws in 3 5 6 7; do
  $aerospace workspace "$ws"
  $aerospace layout accordion
done

# Return to original workspace
$aerospace workspace "$current"
