# ~/.zshrc
# Exit early for non-interactive shells used by IDE agents.
[[ -n "$PAGER" && "$PAGER" == "head -n 10000 | cat" ]] && return

# ==============================================================================
# Main Zsh configuration file.
#
# Sections:
#   1. Plugin Management (zim)
#   2. Nix Environment
#   3. Shell Configuration
#   4. History Settings
#   5. Tool-specific Initializations
#   6. Keybindings
#   7. Local Customizations
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Plugin Management (zim)
# ------------------------------------------------------------------------------
# Zim plugin manager setup. See ~/.config/zsh/zimrc for the list of modules.

ZIM_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zimrc"
ZIM_HOME="$HOME/.zim"
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/powerlevel10k-config/p10k.zsh"

# Download zimfw plugin manager if missing.
if [[ ! -e "$ZIM_HOME/zimfw.zsh" ]]; then
  curl -fsSL --create-dirs -o "$ZIM_HOME/zimfw.zsh" \
      "https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh"
fi

# Install missing modules and update init.zsh if config is newer.
if [[ ! "$ZIM_HOME/init.zsh" -nt "${ZIM_CONFIG_FILE:-${ZDOTDIR:-$HOME}/.zimrc}" ]]; then
  source "$ZIM_HOME/zimfw.zsh" init
fi

# Initialize modules.
source "$ZIM_HOME/init.zsh"


# ------------------------------------------------------------------------------
# 2. Nix Environment
# ------------------------------------------------------------------------------
# Setup for Nix package manager and Home Manager.

# Source Home Manager session variables, but only once.
if [[ -z "$__HM_ZSH_SESS_VARS_SOURCED" ]]; then
  if [[ -f "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh" ]]; then
    source "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
    export __HM_ZSH_SESS_VARS_SOURCED=1
  elif [[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
    source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    export __HM_ZSH_SESS_VARS_SOURCED=1
  fi
fi

# Source Nix profiles.
if [[ -e /etc/profile.d/nix.sh ]]; then source /etc/profile.d/nix.sh; fi

# Add Nix profile completions to fpath.
export NIX_PROFILES="${NIX_PROFILES:-$HOME/.nix-profile}"
for profile in ${(z)NIX_PROFILES}; do
  fpath+=("$profile/share/zsh/site-functions" "$profile/share/zsh/$ZSH_VERSION/functions" "$profile/share/zsh/vendor-completions")
done

# Ensure terminfo database from Nix profile is available.
if [[ -d "$HOME/.nix-profile/share/terminfo" ]]; then
  export TERMINFO_DIRS="${TERMINFO_DIRS:+"$TERMINFO_DIRS:"}$HOME/.nix-profile/share/terminfo"
fi


# ------------------------------------------------------------------------------
# 3. Shell Configuration
# ------------------------------------------------------------------------------

# Set a fallback TERM if the current one is not recognized.
if ! infocmp -L "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# Resolve zsh installation prefix for HELPDIR.
_zsh_bin_path() {
  if command -v realpath >/dev/null; then
    realpath "$(command -v zsh)"
  elif command -v readlink >/dev/null; then
    readlink -f "$(command -v zsh)"
  else
    command -v zsh
  fi
}
ZSH_PREFIX=${$(_zsh_bin_path):h:h}
HELPDIR="$ZSH_PREFIX/share/zsh/$ZSH_VERSION/help"
unset -f _zsh_bin_path

# Set colors for ls.
if command -v dircolors >/dev/null; then
  if [[ -f "$HOME/.dir_colors" ]]; then
    eval "$(dircolors -b "$HOME/.dir_colors")"
  else
    eval "$(dircolors -b)"
  fi
fi

# Increase open file descriptor limit.
ulimit -n unlimited

# Helper function for port-forwarding over SSH.
pfwd() {
  local_host_port=${3:-$2}
  ssh -M -fNT -o ExitOnForwardFailure=yes -L "127.0.0.1:${local_host_port}:127.0.0.1:$2" "$1" &&
    print -P "%F{green}Forwarded → http://127.0.0.1:%f${local_host_port}"
}

# ------------------------------------------------------------------------------
# 4. History Settings
# ------------------------------------------------------------------------------
# Using XDG Base Directory Specification for history file.

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=10000
SAVEHIST=10000

mkdir -p "$(dirname "$HISTFILE")"
setopt HIST_FCNTL_LOCK SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY HIST_REDUCE_BLANKS
unsetopt APPEND_HISTORY EXTENDED_HISTORY


# ------------------------------------------------------------------------------
# 5. Tool-specific Initializations
# ------------------------------------------------------------------------------
# These sections are guarded to only run if the command exists.

# Homebrew
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Micromamba
if command -v micromamba >/dev/null; then
  export MAMBA_EXE="$(command -v micromamba)"
  export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/micromamba}"
  eval "$("$MAMBA_EXE" shell hook --shell zsh --prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"
fi

# Helper hooks (fast initialization)
command -v command-not-found >/dev/null && source "$(command-not-found --print-shell-hook-path zsh 2>/dev/null)"
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Ghostty terminal integration
if [[ -f "$HOME/.nix-profile/zsh/ghostty-integration" ]]; then
  source "$HOME/.nix-profile/zsh/ghostty-integration"
fi

# Load API keys from sops-nix if not already set.
_secrets_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sops-nix/secrets/api_keys"
# Removed OPENAI for now...
# for key in OPAL ASSEMBLYAI HUGGING_FACE_HUB OPENAI ANTHROPIC MISTRAL OPENROUTER GEMINI ARTIFICIAL_ANALYSIS OPENCODE; do
for key in OPAL HUGGING_FACE_HUB ARTIFICIAL_ANALYSIS OPENCODE; do
  var="${key}_API_KEY"
  file="${_secrets_dir}/${(L)key}_api_key"
  [[ -z "${(@P)var}" && -f "$file" ]] && export "$var"="$(<"$file")"
  unset var file
done
unset _secrets_dir

# ------------------------------------------------------------------------------
# 6. Keybindings (ZLE)
# ------------------------------------------------------------------------------

if [[ $options[zle] == on ]]; then
  # Atuin portable keybindings for up/down arrow search.
  if command -v atuin >/dev/null && (( $+widgets[_atuin_up_search_widget] )); then
    bindkey "${terminfo[kcuu1]}" _atuin_up_search_widget
  fi
fi

# ------------------------------------------------------------------------------
# 7. Local Customizations
# ------------------------------------------------------------------------------
# For settings specific to this machine.
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
