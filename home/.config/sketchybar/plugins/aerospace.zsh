#!/usr/bin/env zsh -f

# This plugin handles workspace highlighting for aerospace
# It's triggered by the aerospace_workspace_change event

if [ "$SENDER" = "aerospace_workspace_change" ]; then
  source "$CONFIG_DIR/colors.zsh"

  # Extract workspace ID from the item name (space.mail -> mail)
  WORKSPACE="${NAME#*.}"

  # Determine if this workspace is selected
  # FOCUSED_WORKSPACE is set by aerospace via the trigger
  if [ "$WORKSPACE" = "$FOCUSED_WORKSPACE" ]; then
    SELECTED="true"
    COLOR=$GREY
  else
    SELECTED="false"
    COLOR=$BACKGROUND_2
  fi

  sketchybar --set $NAME \
    icon.highlight=$SELECTED \
    label.highlight=$SELECTED \
    background.border_color=$COLOR
fi
