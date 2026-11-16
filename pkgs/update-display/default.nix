# Updates DISPLAY env variable for tmux panes after SSH reconnection.
{
  lib,
  writeShellApplication,
}:
(writeShellApplication {
  name = "update-display";

  text = ''
    # When re-attaching to an existing tmux session over `ssh -X`, update $DISPLAY
    # in interactive shells and editors from tmux's session environment after
    # strictly validating DISPLAY so shell/vim metacharacters can never execute.

    if [[ -z "''${TMUX:-}" ]]; then
      echo "update-display: must be run inside a tmux session." >&2
      exit 1
    fi

    NEW_DISPLAY=$(tmux show-env | sed -n 's/^DISPLAY=//p')
    if [[ -z "$NEW_DISPLAY" ]]; then
      echo "update-display: DISPLAY is unset in tmux session environment." >&2
      exit 0
    fi

    if [[ ! "$NEW_DISPLAY" =~ ^[A-Za-z0-9_:./-]+$ ]]; then
      echo "ERROR: Refusing unsafe DISPLAY value: $NEW_DISPLAY" >&2
      exit 1
    fi

    while IFS=$'\t' read -r pane_id pane_cmd pane_in_mode; do
      # Do not inject keystrokes into panes currently in tmux copy/view mode.
      if [[ "$pane_in_mode" != "0" ]]; then
        continue
      fi

      case "$pane_cmd" in
        zsh | bash)
          tmux send-keys -t "$pane_id" -l " export DISPLAY='$NEW_DISPLAY'"
          tmux send-keys -t "$pane_id" Enter
          ;;
        vi | vim | nvim)
          tmux send-keys -t "$pane_id" Escape
          tmux send-keys -t "$pane_id" -l ":let \$DISPLAY = '$NEW_DISPLAY'"
          tmux send-keys -t "$pane_id" Enter
          tmux send-keys -t "$pane_id" -l ":silent! xrestore"
          tmux send-keys -t "$pane_id" Enter
          ;;
      esac
    done < <(tmux list-panes -s -F $'#{pane_id}\t#{pane_current_command}\t#{pane_in_mode}')
  '';
})
// {
  meta = with lib; {
    description = "Update DISPLAY env variable.";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
