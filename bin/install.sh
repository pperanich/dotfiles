#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
  case "$(uname -s)" in
  Darwin*)
    echo "darwin"
    ;;
  Linux*)
    echo "linux"
    ;;
  *)
    log_error "Unsupported operating system: $(uname -s)"
    exit 1
    ;;
  esac
}

# Get hostname appropriate for flake references
get_hostname() {
  if [ "$(detect_os)" = "darwin" ]; then
    scutil --get LocalHostName
  else
    hostname -s
  fi
}

# Get the directory where the flake lives (parent of bin/)
get_flake_dir() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$script_dir/.." && pwd
}

# Check system requirements
check_requirements() {
  local required_commands=("curl" "git")
  for cmd in "${required_commands[@]}"; do
    if ! command_exists "$cmd"; then
      log_error "Required command not found: $cmd"
      exit 1
    fi
  done
}

# Source nix environment for the current shell session
source_nix() {
  if command_exists nix; then
    return
  fi

  local nix_daemon_sh="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  if [ -e "$nix_daemon_sh" ]; then
    # nix-daemon.sh can reference unset variables and return non-zero in
    # subexpressions — temporarily relax strict mode while sourcing.
    # (Pattern from DeterminateSystems/macos-ephemeral)
    set +eu
    # shellcheck disable=SC1090
    . "$nix_daemon_sh"
    set -eu
  else
    log_error "Nix is installed but cannot find $nix_daemon_sh"
    log_error "Please restart your shell and re-run this script."
    exit 1
  fi
}

# Install Nix using Determinate Systems installer
install_nix() {
  if command_exists nix; then
    log_info "Nix is already installed: $(nix --version)"
    return
  fi

  log_step "Installing Determinate Nix..."

  # Determinate Nix installer — flakes and nix-command are stable and
  # enabled by default; no channels, no extra configuration needed.
  if curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install; then
    log_info "Nix installed successfully"
    source_nix
    log_info "Nix version: $(nix --version)"
  else
    log_error "Failed to install Nix"
    exit 1
  fi
}

# Setup nix-darwin (macOS)
setup_darwin() {
  local hostname
  hostname="$(get_hostname)"
  local flake_dir
  flake_dir="$(get_flake_dir)"

  log_step "Setting up nix-darwin for ${hostname}..."

  if command_exists darwin-rebuild; then
    log_info "nix-darwin already installed, running switch..."
    darwin-rebuild switch --flake "${flake_dir}#${hostname}"
  else
    log_info "Bootstrapping nix-darwin (first-time install)..."
    nix run nix-darwin -- switch --flake "${flake_dir}#${hostname}"
  fi

  log_info "nix-darwin configuration applied successfully"
}

# Setup NixOS
setup_nixos() {
  local hostname
  hostname="$(get_hostname)"
  local flake_dir
  flake_dir="$(get_flake_dir)"

  log_step "Setting up NixOS for ${hostname}..."

  if [ "$(id -u)" -ne 0 ]; then
    log_info "Running nixos-rebuild with sudo..."
    sudo nixos-rebuild switch --flake "${flake_dir}#${hostname}"
  else
    nixos-rebuild switch --flake "${flake_dir}#${hostname}"
  fi

  log_info "NixOS configuration applied successfully"
}

# Setup standalone home-manager (fallback for non-system-managed hosts)
setup_home_manager() {
  local flake_dir
  flake_dir="$(get_flake_dir)"

  log_step "Setting up standalone home-manager for ${USER}..."

  if command_exists home-manager; then
    log_info "home-manager already installed, running switch..."
    home-manager switch --flake "${flake_dir}#${USER}"
  else
    log_info "Bootstrapping home-manager (first-time install)..."
    nix run home-manager -- switch --flake "${flake_dir}#${USER}"
  fi

  log_info "home-manager configuration applied successfully"
}

# Print usage
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap a Nix-based system configuration from this dotfiles flake.

Options:
  --home-only    Only set up standalone home-manager (skip system config)
  --help         Show this help message

Detected environment:
  OS:       $(detect_os)
  Hostname: $(get_hostname)
  User:     ${USER}
  Flake:    $(get_flake_dir)

What this script does:
  1. Installs Determinate Nix (if not present)
  2. Applies system configuration:
     - macOS: nix-darwin switch (includes home-manager)
     - Linux: nixos-rebuild switch (includes home-manager)
     - --home-only: standalone home-manager switch
EOF
}

# Main installation
main() {
  local home_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --home-only)
      home_only=true
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
  done

  log_info "Starting installation..."
  log_info "OS: $(detect_os) | Host: $(get_hostname) | User: ${USER}"

  # Check requirements
  check_requirements

  install_nix

  if [ "$home_only" = true ]; then
    setup_home_manager
  elif [ "$(detect_os)" = "darwin" ]; then
    setup_darwin
  else
    setup_nixos
  fi

  log_info "Installation completed successfully!"
  log_warn "Please restart your shell to pick up all changes."
}

main "$@"
