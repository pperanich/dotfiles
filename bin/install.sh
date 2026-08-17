#!/usr/bin/env bash
#
# Bootstrap a Nix-based system configuration from this dotfiles flake.
#
#   Remote: curl -fsSL https://raw.githubusercontent.com/pperanich/dotfiles/main/bin/install.sh | bash
#   Local:  ./bin/install.sh
#
# Safe to re-run: every step is gated on the state it produces.

set -Eeuo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/pperanich/dotfiles.git}"
REPO_REF="${DOTFILES_REF:-main}"
CLONE_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
NIX_INSTALLER_URL="${NIX_INSTALLER_URL:-https://install.determinate.systems/nix}"

# Extra profile dirs to search, since a freshly installed Nix, nix-darwin or
# home-manager is not on PATH until the next login shell.
PROFILE_DIRS=(
  "/run/current-system/sw/bin"
  "$HOME/.nix-profile/bin"
  "/nix/var/nix/profiles/default/bin"
)

# Populated by preflight
OS=""
HOSTNAME_DETECTED=""
IS_NIXOS=false
FLAKE_DIR=""
SOURCE_MODE=""
TMP_DIR=""
BOOTSTRAPPED=false

# Set by flags
opt_host=""
opt_mode=""
opt_dir=""
opt_assume_yes=false
opt_dry_run=false

# --- output ---------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[1;33m'
  C_BLUE=$'\033[0;34m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD='' C_RESET=''
fi

log_info() { printf '%s[info]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_step() { printf '%s[step]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_warn() { printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_error() { printf '%s[error]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

on_error() {
  log_error "failed at line $1 (exit $2)"
}
trap 'on_error "$LINENO" "$?"' ERR
trap 'if [ -n "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi' EXIT

# nix-daemon.sh dereferences unset variables and returns non-zero, so strict
# mode and the ERR trap have to stand down while it is sourced.
relax_strict() {
  trap - ERR
  set +eu
}
restore_strict() {
  set -eu
  trap 'on_error "$LINENO" "$?"' ERR
}

# --- helpers --------------------------------------------------------------

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Print the absolute path to $1, searching PATH first and then the Nix profile
# dirs that a not-yet-reloaded shell is missing. Prints nothing and still
# succeeds when absent, so callers in $(...) do not trip the ERR trap.
resolve_cmd() {
  local dir
  if command_exists "$1"; then
    command -v "$1"
    return 0
  fi
  for dir in "${PROFILE_DIRS[@]}"; do
    if [ -x "$dir/$1" ]; then
      printf '%s\n' "$dir/$1"
      return 0
    fi
  done
}

# -r/-w on /dev/tty only test mode bits and pass even with no controlling
# terminal, so actually try to open it. The subshell keeps a redirection
# failure from killing the script.
have_tty() {
  [ -e /dev/tty ] || return 1
  (
    trap - ERR
    exec 3<>/dev/tty
  ) 2>/dev/null
}

confirm() {
  if [ "$opt_assume_yes" = true ]; then
    return 0
  fi
  if ! have_tty; then
    log_error "no terminal available to confirm; re-run with --yes"
    exit 1
  fi
  local reply
  printf '%s%s%s [y/N] ' "$C_BOLD" "$1" "$C_RESET" >/dev/tty
  read -r reply </dev/tty || reply=""
  case "$reply" in
  [yY] | [yY][eE][sS]) return 0 ;;
  *)
    log_info "aborted"
    exit 0
    ;;
  esac
}

tmp_dir() {
  if [ -z "$TMP_DIR" ]; then
    TMP_DIR="$(mktemp -d)"
  fi
  printf '%s\n' "$TMP_DIR"
}

# --- detection ------------------------------------------------------------

detect_os() {
  case "$(uname -s)" in
  Darwin*) printf 'darwin\n' ;;
  Linux*) printf 'linux\n' ;;
  *) return 1 ;;
  esac
}

detect_hostname() {
  if [ "$OS" = darwin ]; then
    scutil --get LocalHostName 2>/dev/null || hostname -s
  else
    hostname -s
  fi
}

# Absolute path of this script, or nothing when it was piped in (curl | bash,
# process substitution) and has no path on disk.
script_path() {
  local src="${BASH_SOURCE[0]:-}"
  case "$src" in
  '' | bash | sh | -* | /dev/fd/* | /proc/self/fd/*) return 0 ;;
  esac
  if [ -f "$src" ]; then
    printf '%s/%s\n' "$(cd "$(dirname "$src")" && pwd)" "$(basename "$src")"
  fi
}

# Prefer the checkout this script was run from; fall back to a managed clone.
resolve_source() {
  if [ -n "$opt_dir" ]; then
    CLONE_DIR="$opt_dir"
  fi

  local self root
  self="$(script_path)"
  if [ -n "$self" ]; then
    root="$(cd "$(dirname "$self")/.." && pwd)"
    if [ -f "$root/flake.nix" ]; then
      FLAKE_DIR="$root"
      SOURCE_MODE="local"
      return 0
    fi
  fi

  FLAKE_DIR="$CLONE_DIR"
  if [ -d "$CLONE_DIR/.git" ]; then
    SOURCE_MODE="update"
  else
    SOURCE_MODE="clone"
  fi
}

# --- steps ----------------------------------------------------------------

check_requirements() {
  local cmd missing=""
  for cmd in curl uname; do
    command_exists "$cmd" || missing="$missing $cmd"
  done
  if [ "$SOURCE_MODE" != local ] && ! command_exists git; then
    missing="$missing git"
  fi
  if [ -n "$missing" ]; then
    log_error "required command(s) not found:$missing"
    exit 1
  fi
}

sync_repo() {
  case "$SOURCE_MODE" in
  local)
    return 0
    ;;
  clone)
    if [ -e "$CLONE_DIR" ]; then
      log_error "$CLONE_DIR exists but is not a git checkout"
      exit 1
    fi
    log_step "Cloning $REPO_URL into $CLONE_DIR"
    git clone --branch "$REPO_REF" "$REPO_URL" "$CLONE_DIR"
    ;;
  update)
    log_step "Updating existing checkout at $CLONE_DIR"
    if [ -n "$(git -C "$CLONE_DIR" status --porcelain)" ]; then
      log_warn "uncommitted changes in $CLONE_DIR, leaving it untouched"
      return 0
    fi
    git -C "$CLONE_DIR" fetch --quiet origin "$REPO_REF"
    git -C "$CLONE_DIR" checkout --quiet "$REPO_REF"
    git -C "$CLONE_DIR" merge --ff-only --quiet "origin/$REPO_REF"
    ;;
  esac
}

# Put nix on PATH if it is installed but the shell predates the install.
load_nix_env() {
  command_exists nix && return 0

  local profile
  for profile in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
    if [ -e "$profile" ]; then
      relax_strict
      # shellcheck disable=SC1090
      . "$profile"
      restore_strict
      break
    fi
  done

  if ! command_exists nix; then
    local nix_bin
    nix_bin="$(resolve_cmd nix)"
    if [ -n "$nix_bin" ]; then
      PATH="$(dirname "$nix_bin"):$PATH"
      export PATH
    fi
  fi
  command_exists nix
}

install_nix() {
  if load_nix_env; then
    log_info "Nix already installed ($(nix --version))"
    return 0
  fi

  log_step "Installing Determinate Nix"
  # --no-confirm because stdin belongs to the curl pipe when this script is
  # itself piped; the confirmation happened in print_plan/confirm instead.
  curl --proto '=https' --tlsv1.2 -fsSL "$NIX_INSTALLER_URL" | sh -s -- install --no-confirm

  if ! load_nix_env; then
    log_error "Nix installed but 'nix' is still not on PATH"
    log_error "open a new shell and re-run this script"
    exit 1
  fi
  BOOTSTRAPPED=true
  log_info "Nix installed ($(nix --version))"
}

sudo_preflight() {
  [ "$(id -u)" -eq 0 ] && return 0
  if ! command_exists sudo; then
    log_error "sudo is required to switch the system configuration"
    exit 1
  fi
  sudo -n true 2>/dev/null && return 0
  log_step "Requesting sudo up front so the build is not interrupted"
  sudo -v
}

current_system() {
  nix eval --raw --impure --expr builtins.currentSystem 2>/dev/null || true
}

# Newline-separated attribute names of a flake output set, empty on failure.
flake_attr_names() {
  nix eval --raw "${FLAKE_DIR}#${1}" \
    --apply 'set: builtins.concatStringsSep "\n" (builtins.attrNames set)' 2>/dev/null || true
}

# Fail loudly with the valid choices instead of letting nix report a missing
# attribute several minutes into evaluation.
require_flake_attr() {
  local output="$1" name="$2" names
  names="$(flake_attr_names "$output")"
  [ -z "$names" ] && return 0
  if printf '%s\n' "$names" | grep -Fxq "$name"; then
    return 0
  fi
  log_error "no ${output}.${name} in this flake"
  log_error "available: $(printf '%s' "$names" | tr '\n' ' ')"
  exit 1
}

switch_darwin() {
  local host="$1"
  require_flake_attr darwinConfigurations "$host"

  local rebuild
  rebuild="$(resolve_cmd darwin-rebuild)"
  if [ -n "$rebuild" ]; then
    log_step "Switching nix-darwin for $host"
    "$rebuild" switch --flake "${FLAKE_DIR}#${host}"
    return 0
  fi

  # First run: build this flake's own darwin-rebuild rather than `nix run
  # nix-darwin`, which resolves to master and asserts on the nixpkgs release.
  BOOTSTRAPPED=true
  log_step "Bootstrapping nix-darwin for $host (first run)"
  local out
  out="$(tmp_dir)/darwin-system"
  nix build --out-link "$out" "${FLAKE_DIR}#darwinConfigurations.${host}.system"
  "$out/sw/bin/darwin-rebuild" switch --flake "${FLAKE_DIR}#${host}"
}

switch_nixos() {
  local host="$1"
  require_flake_attr nixosConfigurations "$host"

  local rebuild
  rebuild="$(resolve_cmd nixos-rebuild)"
  if [ -z "$rebuild" ]; then
    log_error "nixos-rebuild not found; this does not look like a NixOS system"
    log_error "use --home-only for standalone home-manager instead"
    exit 1
  fi

  log_step "Switching NixOS for $host"
  if [ "$(id -u)" -eq 0 ]; then
    "$rebuild" switch --flake "${FLAKE_DIR}#${host}"
  else
    sudo "$rebuild" switch --flake "${FLAKE_DIR}#${host}"
  fi
}

switch_home_manager() {
  local user="$1"
  require_flake_attr homeConfigurations "$user"

  # This flake pins homeConfigurations to a single system; refuse early rather
  # than fail deep in the build on a mismatched host.
  local want have
  want="$(nix eval --raw "${FLAKE_DIR}#homeConfigurations.${user}.pkgs.system" 2>/dev/null || true)"
  have="$(current_system)"
  if [ -n "$want" ] && [ -n "$have" ] && [ "$want" != "$have" ]; then
    log_error "homeConfigurations.${user} is built for $want, this machine is $have"
    log_error "adjust the pinned system in modules/flake-parts/home.nix"
    exit 1
  fi

  local hm
  hm="$(resolve_cmd home-manager)"
  if [ -n "$hm" ]; then
    log_step "Switching home-manager for $user"
    "$hm" switch --flake "${FLAKE_DIR}#${user}"
    return 0
  fi

  # Activate the flake's own home-manager rather than `nix run home-manager`,
  # which resolves to master and can disagree with the locked release.
  BOOTSTRAPPED=true
  log_step "Bootstrapping home-manager for $user (first run)"
  local out
  out="$(tmp_dir)/home-manager"
  nix build --out-link "$out" "${FLAKE_DIR}#homeConfigurations.${user}.activationPackage"
  "$out/activate"
}

# --- plan -----------------------------------------------------------------

plan_action() {
  case "$opt_mode" in
  home) printf 'home-manager switch  ->  %s#%s\n' "$FLAKE_DIR" "${opt_host:-$USER}" ;;
  darwin) printf 'darwin-rebuild switch  ->  %s#%s\n' "$FLAKE_DIR" "$opt_host" ;;
  nixos) printf 'nixos-rebuild switch  ->  %s#%s\n' "$FLAKE_DIR" "$opt_host" ;;
  esac
}

plan_source() {
  case "$SOURCE_MODE" in
  local) printf '%s (existing checkout)\n' "$FLAKE_DIR" ;;
  clone) printf '%s (clone %s @ %s)\n' "$FLAKE_DIR" "$REPO_URL" "$REPO_REF" ;;
  update) printf '%s (update to %s)\n' "$FLAKE_DIR" "$REPO_REF" ;;
  esac
}

plan_nix() {
  if load_nix_env; then
    nix --version
  else
    printf 'not installed (will install Determinate Nix)\n'
  fi
}

print_plan() {
  printf '\n%sdotfiles installer%s\n\n' "$C_BOLD" "$C_RESET"
  printf '  %-10s %s\n' "Source" "$(plan_source)"
  printf '  %-10s %s (%s)\n' "System" "$OS" "$(uname -m)"
  if [ "$opt_mode" != home ]; then
    printf '  %-10s %s\n' "Host" "$opt_host"
  fi
  printf '  %-10s %s\n' "User" "$USER"
  printf '  %-10s %s\n' "Nix" "$(plan_nix)"
  printf '  %-10s %s\n' "Action" "$(plan_action)"
  printf '\n'
}

usage() {
  cat <<'EOF'
Bootstrap a Nix-based system configuration from this dotfiles flake.

Usage:
  install.sh [options]
  curl -fsSL https://raw.githubusercontent.com/pperanich/dotfiles/main/bin/install.sh | bash

Options:
  --host <name>   Flake configuration to apply (default: this machine's hostname)
  --home-only     Apply standalone home-manager instead of the system config
  --dir <path>    Where to clone the repo when not run from a checkout
  --ref <ref>     Branch or tag to clone/update (default: main)
  --repo <url>    Repository to clone (default: github.com/pperanich/dotfiles)
  --dry-run       Print the plan and exit without changing anything
  -y, --yes       Skip the confirmation prompt
  -h, --help      Show this help

Environment:
  DOTFILES_DIR    Same as --dir
  DOTFILES_REF    Same as --ref
  DOTFILES_REPO   Same as --repo
  NO_COLOR        Disable coloured output

Steps:
  1. Clone or fast-forward the flake checkout
  2. Install Determinate Nix if absent
  3. Switch the configuration:
       macOS   nix-darwin       (includes home-manager)
       NixOS   nixos-rebuild    (includes home-manager)
       --home-only  standalone home-manager
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --host)
      opt_host="${2:-}"
      [ -n "$opt_host" ] || {
        log_error "--host requires a value"
        exit 1
      }
      shift 2
      ;;
    --dir)
      opt_dir="${2:-}"
      [ -n "$opt_dir" ] || {
        log_error "--dir requires a value"
        exit 1
      }
      shift 2
      ;;
    --ref)
      REPO_REF="${2:-}"
      [ -n "$REPO_REF" ] || {
        log_error "--ref requires a value"
        exit 1
      }
      shift 2
      ;;
    --repo)
      REPO_URL="${2:-}"
      [ -n "$REPO_URL" ] || {
        log_error "--repo requires a value"
        exit 1
      }
      shift 2
      ;;
    --home-only)
      opt_mode="home"
      shift
      ;;
    --dry-run)
      opt_dry_run=true
      shift
      ;;
    -y | --yes)
      opt_assume_yes=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      log_error "unknown option: $1"
      printf '\n'
      usage >&2
      exit 1
      ;;
    esac
  done
}

main() {
  parse_args "$@"

  if ! OS="$(detect_os)"; then
    log_error "unsupported operating system: $(uname -s)"
    exit 1
  fi
  if [ -e /etc/NIXOS ]; then
    IS_NIXOS=true
  fi

  resolve_source
  check_requirements

  HOSTNAME_DETECTED="$(detect_hostname 2>/dev/null || true)"
  if [ -z "$opt_mode" ]; then
    if [ "$OS" = darwin ]; then
      opt_mode="darwin"
    elif [ "$IS_NIXOS" = true ]; then
      opt_mode="nixos"
    else
      log_info "not a NixOS system, falling back to standalone home-manager"
      opt_mode="home"
    fi
  fi
  if [ -z "$opt_host" ] && [ "$opt_mode" != home ]; then
    opt_host="$HOSTNAME_DETECTED"
    [ -n "$opt_host" ] || {
      log_error "could not determine hostname; pass --host"
      exit 1
    }
  fi

  print_plan
  if [ "$opt_dry_run" = true ]; then
    log_info "dry run, nothing to do"
    exit 0
  fi
  confirm "Proceed?"

  sync_repo
  install_nix
  if [ "$opt_mode" = nixos ]; then
    sudo_preflight
  fi

  case "$opt_mode" in
  darwin) switch_darwin "$opt_host" ;;
  nixos) switch_nixos "$opt_host" ;;
  home) switch_home_manager "${opt_host:-$USER}" ;;
  esac

  printf '\n'
  log_info "done"
  if [ "$BOOTSTRAPPED" = true ]; then
    log_info "open a new shell to pick up the new PATH"
  fi
}

main "$@"
