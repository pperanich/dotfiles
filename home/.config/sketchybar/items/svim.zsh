#!/usr/bin/env zsh -f

svim=(
  script="$PLUGIN_DIR/svim.zsh"
  icon=$INSERT_MODE
  icon.font.size=20
  updates=on
  drawing=off
)

sketchybar --add event svim_update \
  --add item svim right \
  --set svim "${svim[@]}" \
  --subscribe svim svim_update
