#!/usr/bin/env zsh -f

source "$CONFIG_DIR/icons.zsh"

wifi=(
  padding_right=7
  label.width=0
  icon="$WIFI_DISCONNECTED"
  script="$PLUGIN_DIR/wifi.zsh"
)

sketchybar --add item wifi right \
  --set wifi "${wifi[@]}" \
  --subscribe wifi wifi_change mouse.clicked
