# shellcheck shell=bash
# Usage: dotfiles-sync DIR REV. Fast-forwards DIR to REV, the deployed commit;
# anything that would lose work or move backwards is skipped with a reason.

dir=${1:?usage: dotfiles-sync DIR REV}
rev=${2:-}

say() { printf 'dotfiles-sync: %s\n' "$*"; }
skip() {
	say "leaving $dir as it is: $*"
	exit 0
}
git_() { git -C "$dir" "$@"; }

[[ -n $rev ]] || skip "the deployed flake had uncommitted changes, so it has no commit to sync to"
git_ rev-parse --git-dir >/dev/null 2>&1 || skip "not a git checkout"

head=$(git_ rev-parse HEAD)
[[ $head != "$rev" ]] || exit 0

# Untracked files are ignored: a fast-forward refuses to overwrite one anyway.
[[ -z $(git_ status --porcelain --untracked-files=no) ]] || skip "tracked files have local changes"
branch=$(git_ symbolic-ref --quiet --short HEAD || true)
[[ $branch == main ]] || skip "checked out ${branch:-a detached HEAD}, not main"

if ! git_ cat-file -e "$rev^{commit}" 2>/dev/null; then
	# No prompts: activation has no terminal, and a credential or key-touch
	# request would hang it until the timeout.
	if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
		timeout 30 git -C "$dir" fetch --quiet origin main; then
		skip "fetching origin failed"
	fi
	git_ cat-file -e "$rev^{commit}" 2>/dev/null || skip "commit ${rev:0:12} is not on origin/main yet (push it first)"
fi

if git_ merge-base --is-ancestor "$rev" HEAD; then
	skip "it already contains ${rev:0:12}"
fi
git_ merge-base --is-ancestor HEAD "$rev" || skip "main has commits that ${rev:0:12} does not"

git_ merge --ff-only --quiet "$rev" || skip "fast-forward to ${rev:0:12} failed"
say "fast-forwarded $dir from ${head:0:12} to ${rev:0:12}"
