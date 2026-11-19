#!/usr/bin/env bash
# Update every flake input except the ones pinned on purpose. A bare `nix flake update`
# also bumps pinned inputs and their own nixpkgs, which turns cached outputs into rebuilds.
#
#   bin/update-inputs.sh            update all unpinned inputs
#   bin/update-inputs.sh nixpkgs    update only the named inputs (pins still refused)
set -euo pipefail

# Inputs updated only by hand, each with the reason.
pinned=(
	nix-apple-fonts # built on its own nixpkgs; any bump re-downloads and re-patches every font
	nixpkgs-mongodb # UniFi's MongoDB: unfree, never cached, hours to compile on the router
)

cd "$(git rev-parse --show-toplevel)"

is_pinned() {
	local name=$1 p
	for p in "${pinned[@]}"; do
		[[ $p == "$name" ]] && return 0
	done
	return 1
}

if (($# > 0)); then
	inputs=("$@")
else
	mapfile -t inputs < <(jq -r '.nodes.root.inputs | keys[]' flake.lock)
fi

targets=()
for name in "${inputs[@]}"; do
	if is_pinned "$name"; then
		echo "skipping pinned input: $name (update it with: nix flake update $name)" >&2
	else
		targets+=("$name")
	fi
done

((${#targets[@]} > 0)) || {
	echo "nothing to update" >&2
	exit 0
}

nix flake update "${targets[@]}"
