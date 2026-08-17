#!/usr/bin/env bash
# Load the profiles from this directory; run it from here.

set -euo pipefail

dconf load /org/gnome/terminal/legacy/profiles:/ <gnome-terminal-profiles.dconf
