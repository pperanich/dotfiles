#!/usr/bin/env bash
# Check that a private flake input is fetched only by the hosts that use it, as seen by
# a machine that cannot reach it. Tests the committed HEAD in a throwaway worktree.
#
#   bin/check-private-input.sh feed-me pp-nas1     input, then the hosts that import it
set -euo pipefail

(($# >= 1)) || {
	echo "usage: $0 <input> [host-that-uses-it ...]" >&2
	exit 2
}
input=$1
shift
users=("$@")

repo=$(git rev-parse --show-toplevel)
cd "$repo"

type=$(jq -r --arg n "$input" '.nodes[$n].original.type // "missing"' flake.lock)
[[ $type == git ]] || {
	echo "$input: lock entry type is '$type'; only git inputs are supported" >&2
	exit 2
}

echo "building upstream Nix to compare against Determinate..." >&2
upstream_nix=$(nix build --no-link --print-out-paths --inputs-from . 'nixpkgs#nixVersions.latest^out')/bin/nix

tmp=$(mktemp -d)
wt=$tmp/wt
cleanup() {
	git -C "$repo" worktree remove --force "$wt" 2>/dev/null || true
	rm -rf "$tmp"
}
trap cleanup EXIT
git worktree add --quiet --detach "$wt" HEAD

# Point the input at a host that cannot resolve, with a hash no store path has, so
# neither the network nor a cached copy can satisfy a fetch.
real=$(jq -r --arg n "$input" '.nodes[$n].original.url' "$wt/flake.lock")
fake="ssh://git@unreachable.invalid/$input.git"
nix_src=$(<"$wt/flake.nix")
[[ $nix_src == *"$real"* ]] || {
	echo "$input: '$real' from flake.lock not found in flake.nix" >&2
	exit 2
}
printf '%s\n' "${nix_src//"$real"/"$fake"}" >"$wt/flake.nix"
jq --arg n "$input" --arg u "$fake" '
	.nodes[$n].original.url = $u
	| .nodes[$n].locked.url = $u
	| .nodes[$n].locked.narHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
' "$repo/flake.lock" >"$wt/flake.lock"
git -C "$wt" add flake.nix flake.lock

failures=0
# expect <pass|fail> <label> <command...>; runs in the worktree.
expect() {
	local want=$1 label=$2 got
	shift 2
	if (cd "$wt" && "$@") >"$tmp/out" 2>&1; then got=pass; else got=fail; fi
	# A failure counts only if it is the blocked fetch, not some unrelated eval error.
	[[ $got == fail ]] && ! grep -q 'unreachable.invalid' "$tmp/out" && got="fail (other error)"
	if [[ $got == "$want" ]]; then
		printf 'ok    %-50s %s\n' "$label" "$got"
	else
		printf 'FAIL  %-50s expected %s, got %s\n' "$label" "$want" "$got"
		grep 'error:' "$tmp/out" | tail -1 | sed 's/^ */      /' || true
		failures=$((failures + 1))
	fi
}

det=(nix --option eval-cache false)
up=("$upstream_nix" --extra-experimental-features "nix-command flakes" --option eval-cache false)
is_user() {
	local h
	for h in "${users[@]}"; do [[ $h == "$1" ]] && return 0; done
	return 1
}

expect pass "lock is current (nix flake lock)" "${det[@]}" flake lock
expect pass "update another input (flake-parts)" "${det[@]}" flake update flake-parts
git -C "$wt" checkout --quiet flake.lock

names() { (cd "$wt" && "${det[@]}" eval --raw ".#$1" --apply 'xs: toString (builtins.attrNames xs)' 2>/dev/null); }

templates=$(names templates)
for t in $templates; do
	expect pass "template $t (determinate)" "${det[@]}" eval ".#templates.$t.description"
	expect pass "template $t (upstream)" "${up[@]}" eval ".#templates.$t.description"
done

for class in nixos darwin; do
	hosts=$(names "${class}Configurations")
	for h in $hosts; do
		attr=".#${class}Configurations.$h.config.system.build.toplevel.drvPath"
		if is_user "$h"; then
			expect fail "$h needs $input" "${det[@]}" eval "$attr"
		else
			expect pass "$h evaluates" "${det[@]}" eval "$attr"
		fi
	done
done

ds=$tmp/downstream
cp -r "$repo/templates/private" "$ds"
sed -i "s|github:you/your-config|path:$wt|" "$ds/flake.nix"
for impl in det up; do
	declare -n cmd=$impl
	rm -f "$ds/flake.lock"
	expect pass "downstream flake update ($impl)" "${cmd[@]}" flake update --flake "path:$ds"
	expect pass "downstream flake check --no-build ($impl)" "${cmd[@]}" flake check --no-build "path:$ds"
done

if ((failures > 0)); then
	echo "$failures check(s) did not match" >&2
	exit 1
fi
echo "$input is fetched only by: ${users[*]:-no host}"
