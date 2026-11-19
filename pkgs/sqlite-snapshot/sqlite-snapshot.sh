# shellcheck shell=bash
set -euo pipefail

usage() {
	echo "usage: sqlite-snapshot --out-dir DIR [--timeout DURATION] NAME=PATH..." >&2
	exit 2
}

out_dir=""
duration="15m"
specs=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	--out-dir)
		[[ $# -ge 2 ]] || usage
		out_dir="$2"
		shift 2
		;;
	--timeout)
		[[ $# -ge 2 ]] || usage
		duration="$2"
		shift 2
		;;
	-h | --help) usage ;;
	--)
		shift
		specs+=("$@")
		break
		;;
	-*)
		echo "sqlite-snapshot: unknown option '$1'" >&2
		usage
		;;
	*)
		specs+=("$1")
		shift
		;;
	esac
done

[[ -n $out_dir && ${#specs[@]} -gt 0 ]] || usage

umask 077
if [[ ! -d $out_dir ]]; then
	install -d -m 0700 -- "$out_dir"
fi

exec 9>"$out_dir/.lock"
if ! flock -w 600 9; then
	echo "sqlite-snapshot: could not lock $out_dir/.lock within 600s; another snapshot is still running" >&2
	exit 1
fi

tmp=""
cleanup() {
	if [[ -n $tmp ]]; then
		rm -f -- "$tmp"
	fi
}
trap cleanup EXIT

for spec in "${specs[@]}"; do
	if [[ $spec != *=* ]]; then
		echo "sqlite-snapshot: expected NAME=PATH, got '$spec'" >&2
		exit 2
	fi
	name="${spec%%=*}"
	src="${spec#*=}"

	if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
		echo "sqlite-snapshot: invalid name '$name'; use [A-Za-z0-9._-]+" >&2
		exit 2
	fi
	if [[ ! -f $src ]]; then
		echo "expected SQLite database for '$name' not found at $src" >&2
		exit 1
	fi

	tmp="$out_dir/.$name.$$.tmp"
	rm -f -- "$tmp"
	# VACUUM INTO reads one consistent snapshot and, unlike .backup, does not restart when a writer commits.
	if ! timeout -k 30s "$duration" sqlite3 "$src" ".timeout 30000" "VACUUM INTO '${tmp//\'/\'\'}'"; then
		echo "sqlite-snapshot: snapshot of '$name' from $src failed or exceeded $duration" >&2
		exit 1
	fi
	chmod 0600 -- "$tmp"
	mv -f -- "$tmp" "$out_dir/$name.sqlite3"
	tmp=""
done
