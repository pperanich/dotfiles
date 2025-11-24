#!/usr/bin/env zsh -f

# Add aerospace workspace change event
sketchybar --add event aerospace_workspace_change

# Get all workspaces from aerospace
workspaces=($(aerospace list-workspaces --all))

# Create a space item for each workspace
for sid in "${workspaces[@]}"
do
  space=(
    icon="$sid"
    icon.padding_left=10
    icon.padding_right=10
    padding_left=2
    padding_right=2
    label.padding_right=20
    icon.highlight_color=$RED
    label.color=$GREY
    label.highlight_color=$WHITE
    label.font="sketchybar-app-font:Regular:16.0"
    label.y_offset=-1
    background.color=$BACKGROUND_1
    background.border_color=$BACKGROUND_2
    script="$PLUGIN_DIR/aerospace.zsh"
    click_script="aerospace workspace $sid"
  )

  sketchybar --add item space.$sid left    \
             --set space.$sid "${space[@]}" \
             --subscribe space.$sid aerospace_workspace_change mouse.clicked
done
