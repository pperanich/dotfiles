#!/bin/sh

if [[ "$1" == "ON" ]]; then
MAIN_1=colour51 # Cyan1
MAIN_2=colour50 # Cyan2
MAIN_3=colour43 # Cyan3
elif [[ "$1" == "OFF" ]]; then
MAIN_1=colour214 # Orange1
MAIN_2=colour208 # DarkOrange
MAIN_3=colour172 # Orange3
else
echo "Theme state not detected! Exiting..."
return
fi

ACTIVE_PANE=colour9 # Red
CLOCK=colour109 # LightSkyBlue3
ALT_1=colour167 # IndianRed
ALT_2=colour7 # Silver
# The grays go from darkest to lightest below.
GREY_1=colour232 # Grey3
GREY_2=colour234 # Grey11
GREY_3=colour236 # Grey19
GREY_4=colour238 # Grey27
GREY_5=colour243 # Grey46
GREY_6=colour245 # Grey54

# Length of tmux status line
tmux set -g status-left-length 30
tmux set -g status-right-length 150

tmux set-option -g status "on"

# Default statusbar color
tmux set-option -g status-style "bg=$GREY_2,fg=$MAIN_3"

# Default window title colors
tmux set-window-option -g window-status-style "bg=$MAIN_1,fg=$GREY_2"

# Default window with an activity alert
tmux set-window-option -g window-status-activity-style "bg=$GREY_2,fg=$GREY_6"

# Active window title colors
tmux set-window-option -g window-status-current-style "bg=$ACTIVE_PANE,fg=$GREY_2"

# tmux set active pane border color
tmux set-option -g pane-active-border-style "fg=$MAIN_2"

# tmux set inactive pane border color
tmux set-option -g pane-border-style "fg=$GREY_3"

# Message info
tmux set-option -g message-style "bg=$GREY_3,fg=$MAIN_3"

# Writing commands inactive
tmux set-option -g message-command-style "bg=$GREY_3,fg=$MAIN_3"

# Pane number display
tmux set-option -g display-panes-active-colour "colour1"
tmux set-option -g display-panes-colour "$GREY_2"

# Clock
tmux set-window-option -g clock-mode-colour "$CLOCK"

# Bell
tmux set-window-option -g window-status-bell-style "bg=$ALT_1,fg=$GREY_1"

tmux set-option -g status-left "\
#[fg=$ALT_2, bg=$GREY_4]#{?client_prefix,#[bg=$ALT_1],} ❐ #S \
#[fg=$GREY_4, bg=$GREY_2]#{?client_prefix,#[fg=$ALT_1],}#{?window_zoomed_flag, 🔍,}"

tmux set-option -g status-right "\
#[fg=$MAIN_1, bg=$GREY_2] \
#[fg=$GREY_2, bg=$MAIN_1] #(~/dotfiles/tmux/scripts/music.sh) \
#[fg=$MAIN_3, bg=$GREY_2] #(~/dotfiles/tmux/scripts/uptime.sh) \
#[fg=$GREY_5, bg=$GREY_2]  %b %d '%y\
#[fg=$CLOCK]  %H:%M \
#[fg=$GREY_6, bg=$GREY_3]"

tmux set-window-option -g window-status-current-format "\
#[fg=$GREY_2, bg=$MAIN_1]\
#[fg=$GREY_3, bg=$MAIN_1] #I* \
#[fg=$GREY_3, bg=$MAIN_1, bold] #W \
#[fg=$MAIN_1, bg=$GREY_2]"

tmux set-window-option -g window-status-format "\
#[fg=$GREY_2,bg=$GREY_3,noitalics]\
#[fg=$MAIN_3,bg=$GREY_3] #I \
#[fg=$MAIN_3, bg=$GREY_3] #W \
#[fg=$GREY_3, bg=$GREY_2]"
