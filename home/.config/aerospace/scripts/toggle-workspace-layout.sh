#!/bin/bash
# Toggle the focused workspace between tiles and accordion.
# `aerospace layout` on its own only retiles the focused window's parent
# container, so nested splits keep their old layout. --root targets the
# workspace root instead, which flips the whole workspace at once.
# Orientation (horizontal/vertical) is preserved by the cycle.

set -euo pipefail

aerospace=/opt/homebrew/bin/aerospace

ws=$($aerospace list-workspaces --focused)
$aerospace layout --workspace "$ws" --root tiles accordion
