if [[ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]]; then
  source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
fi

if [[ -e /etc/profile.d/nix.sh ]]; then
  # shellcheck disable=SC1091
  . /etc/profile.d/nix.sh
fi
if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  # shellcheck disable=SC1091
  . ~/.nix-profile/etc/profile.d/nix.sh
fi

if [ -f ~/.nix-profile/zsh/ghostty-integration ]; then
  # shellcheck disable=SC1091
  . ~/.nix-profile/zsh/ghostty-integration
fi

if [[ -S /nix/var/nix/daemon-socket/socket ]]; then
  export NIX_REMOTE=daemon
fi

export NIX_USER_PROFILE_DIR=${NIX_USER_PROFILE_DIR:-/nix/var/nix/profiles/per-user/${USER}}
export NIX_PROFILES=${NIX_PROFILES:-$HOME/.nix-profile}

if [[ -z "$TERMINFO_DIRS" ]] || [[ -d $HOME/.nix-profile/share/terminfo ]]; then
  export TERMINFO_DIRS=$HOME/.nix-profile/share/terminfo
fi

# Resolve zsh prefix even if the binary is a symlink
if command -v realpath >/dev/null; then
  _zsh_bin=$(realpath "$(command -v zsh)")
elif command -v readlink >/dev/null; then
  _zsh_bin=$(readlink -f "$(command -v zsh)")
else
  _zsh_bin="$(command -v zsh)"
fi
ZSH_PREFIX="${_zsh_bin:h:h}"
HELPDIR="$ZSH_PREFIX/share/zsh/$ZSH_VERSION/help"
unset _zsh_bin

# Add completion dirs from Nix profiles
for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done

# dircolors
if command -v dircolors >/dev/null; then
  if [[ -f ~/.dir_colors ]]; then
    eval "$(dircolors -b ~/.dir_colors)"
  else
    eval "$(dircolors -b)"
  fi
fi

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"
setopt HIST_FCNTL_LOCK SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY HIST_REDUCE_BLANKS
unsetopt APPEND_HISTORY EXTENDED_HISTORY

# Micromamba
if command -v micromamba >/dev/null; then
  export MAMBA_EXE="$(command -v micromamba)"
  export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/micromamba}"
  eval "$("$MAMBA_EXE" shell hook --shell zsh --prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"
fi

# Port‑forward helper
pfwd () {
  local_host_port=${3:-$2}
  ssh -M -fNT -o ExitOnForwardFailure=yes -L "127.0.0.1:${local_host_port}:127.0.0.1:$2" "$1" &&
    print -P "%F{green}Forwarded → http://127.0.0.1:%f${local_host_port}"
}

# Load API keys from sops‑nix if not already set
_secrets_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sops-nix/secrets/api_keys"
for key in OPAL OPENAI ASSEMBLYAI HUGGING_FACE_HUB ANTHROPIC MISTRAL OPENROUTER GEMINI; do
  var="${key}_API_KEY"
  file="${_secrets_dir}/${(L)key}_api_key"
  [[ -z ${(@P)var} && -f $file ]] && export $var="$(<$file)"
  unset var file
done
unset _secrets_dir

# Helper hooks (fast initialization)
command -v command-not-found >/dev/null && source "$(command-not-found --print-shell-hook-path zsh 2>/dev/null)"
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)" # Use keybinds below for more control
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
# command -v starship >/dev/null && eval "$(starship init zsh)"
# command -v oh-my-posh >/dev/null && eval "$(oh-my-posh init zsh)"
# if command -v oh-my-posh >/dev/null && [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
#   eval "$(oh-my-posh init zsh --config ${XDG_CONFIG_HOME:-$HOME/.config}/ohmyposh/powerlevel10k_lean.toml)"
# fi

# ZLE (Zsh Line Editor) and Keybindings
if [[ $options[zle] == on ]]; then
  # Atuin portable keybindings
  if command -v atuin >/dev/null && (( $+widgets[_atuin_up_search_widget] )); then
    bindkey "${terminfo[kcuu1]}" _atuin_up_search_widget
    bindkey "${terminfo[kcud1]}" _atuin_down_search_widget
  fi
fi

# Aliases
# alias ll='ls -la'
# if ls --color=auto &>/dev/null; then
#   alias ls='ls --color=auto'
# else
#   alias ls='ls -G'
# fi

# Plugin Management
ZIM_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zimrc"
ZIM_HOME=~/.zim
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/powerlevel10k-config/p10k.zsh"

# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi

# Install missing modules and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi

# Initialize modules.
source ${ZIM_HOME}/init.zsh

# export PATH=$HOME/.cargo/bin:$PATH;
