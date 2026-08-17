#!/usr/bin/env bash

set -euo pipefail

dconf load /org/gnome/terminal/legacy/profiles:/ \
  <"$HOME/.config/gnome-terminal/gnome-terminal-profiles.dconf"
