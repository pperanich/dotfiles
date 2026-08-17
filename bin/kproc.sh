#!/usr/bin/env bash
# Kill every process whose full command line matches the given pattern.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $(basename "$0") <pattern>" >&2
  exit 1
fi

pkill -9 -f "$1"
