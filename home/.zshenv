skip_global_compinit=1

# A nix-shell TMPDIR is long enough to push unix socket paths past macOS's
# sun_path limit (fzf-lua in nvim fails with ENOTSOCK) and it disappears when
# the shell that created it exits. Do not inherit one.
if [[ -n ${TMPDIR:-} && $TMPDIR == */nix-shell.* ]]; then
  unset TMPDIR
fi
