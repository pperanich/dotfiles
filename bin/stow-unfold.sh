#!/usr/bin/env bash
# Turn directories Stow folded into the dotfiles repo back into real directories. Untracked
# files inside a fold are runtime data apps wrote through the link; they move back to $HOME.
#
#   bin/stow-unfold.sh            list each fold and every move, change nothing
#   bin/stow-unfold.sh --apply    unfold, move the data, restow with --no-folding
set -euo pipefail

apply=false
case ${1:-} in
--apply) apply=true ;;
"") ;;
*)
	echo "usage: $0 [--apply]" >&2
	exit 2
	;;
esac

repo=$(cd "${DOTFILES_DIR:-$HOME/dotfiles}" && pwd -P)
stow=${STOW:-stow}
command -v "$stow" >/dev/null || {
	echo "stow not found; run through: nix shell nixpkgs#stow -c $0 $*" >&2
	exit 1
}
log=$HOME/stow-unfold-$(date +%Y%m%d-%H%M%S).log

run() {
	if $apply; then
		"$@"
	else
		printf '  would run:'
		printf ' %q' "$@"
		printf '\n'
	fi
}

# A fold is a directory link at the same relative path as the repo directory it points to.
folds=()
while IFS= read -r -d '' link; do
	[[ -d $link ]] || continue
	target=$(cd "$link" 2>/dev/null && pwd -P) || continue
	[[ $target == "$repo/home/${link#"$HOME"/}" ]] && folds+=("$link")
done < <(find "$HOME" -maxdepth 4 -type l -print0 2>/dev/null)

if ((${#folds[@]} == 0)); then
	echo "No folded directories under $HOME."
	exit 0
fi

for link in "${folds[@]}"; do
	rel=${link#"$HOME"/}
	echo "unfold ~/$rel"
	# Untracked includes ignored files here: without --exclude-standard, git lists both.
	extras=()
	while IFS= read -r -d '' entry; do
		extras+=("${entry%/}")
	done < <(git -C "$repo" ls-files --others --directory -z -- "home/$rel")
	run rm -- "$link"
	run mkdir -p -- "$link"
	for entry in "${extras[@]}"; do
		dest=$HOME/${entry#home/}
		echo "  move $entry -> ~/${entry#home/}"
		run mkdir -p -- "$(dirname -- "$dest")"
		run mv -n -- "$repo/$entry" "$dest"
		if $apply; then
			if [[ -e $repo/$entry || -L $repo/$entry ]]; then
				echo "  WARNING: $repo/$entry was not moved; $dest already exists" >&2
			else
				printf '%s\t%s\n' "$repo/$entry" "$dest" >>"$log"
			fi
		fi
	done
done

run "$stow" -d "$repo" -t "$HOME" --restow --no-folding home
if $apply; then
	echo "Done. Moves are listed in $log (repo path, then new path)."
else
	echo "Dry run. Re-run with --apply to make these changes."
fi
