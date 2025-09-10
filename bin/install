#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    log_error "Unsupported operating system"
    exit 1
    ;;
  esac
}

# Check system requirements
check_requirements() {

  # Check for required commands
  local required_commands=("curl" "git")
  for cmd in "${required_commands[@]}"; do
    if ! command_exists "$cmd"; then
      log_error "Required command not found: $cmd"
      exit 1
    fi
  done
}

# Install Nix
install_nix() {
  if command_exists nix; then
    log_info "Nix is already installed"
    return
  fi

  log_info "Installing Nix..."

  if [ "$(detect_os)" = "darwin" ]; then
    # macOS installation
    if ! command_exists brew && [ ! -d "/opt/homebrew" ]; then
      log_warn "Homebrew not found. Some dependencies might be missing."
    fi
  fi

  # Use determinate systems installer for better reliability
  if curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate; then
    log_info "Nix installed successfully"
    # Source nix
    if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    else
      log_error "Cannot find nix.sh, please restart your shell"
      exit 1
    fi
  else
    log_error "Failed to install Nix"
    exit 1
  fi
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

# Configure Nix
configure_nix() {
  local nix_conf_dir="/etc/nix"
  local nix_conf="$nix_conf_dir/nix.conf"

  # Create nix.conf if it doesn't exist
  if [ ! -f "$nix_conf" ]; then
    if [ "$(detect_os)" = "darwin" ]; then
      sudo mkdir -p "$nix_conf_dir"
    fi
    sudo touch "$nix_conf"
  fi

  # Add experimental features if not present
  if ! grep -q "experimental-features" "$nix_conf"; then
    log_info "Enabling flakes and nix-command features..."
    echo "experimental-features = nix-command flakes" | sudo tee -a "$nix_conf"
  fi
}

# Add channels
add_nix_channels() {
  # Now, add nix and home-manager channels.
  if ! (echo $(nix-channel --list) | grep -q "nixpkgs"); then
    log_info "Add nixpkgs unstable channel"
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
  fi
  if ! (echo $(nix-channel --list) | grep -q "home-manager"); then
    log_info "Add home-manager channel"
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
  fi
  nix-channel --update
}

# Setup home-manager
setup_home_manager() {
  log_info "Setting up home-manager..."

  # Export NIX_PATH
  export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}

  # Check if home-manager is already installed
  if ! command_exists home-manager; then
    log_info "Installing home-manager..."
    nix-shell '<home-manager>' -A install
  fi

  # Apply configuration
  log_info "Applying home-manager configuration..."
  if home-manager switch --flake .#"$USER" --impure --keep-going; then
    log_info "home-manager configuration applied successfully"
  else
    log_error "Failed to apply home-manager configuration"
    exit 1
  fi
}

# Setup Darwin
setup_darwin() {
  if [ "$(detect_os)" = "darwin" ]; then
    log_info "Setting up Darwin configuration..."

    # Check if darwin-rebuild is available
    if ! command_exists darwin-rebuild; then
      log_info "Installing nix-darwin..."
      nix build .#darwinConfigurations."$(hostname -s)".system
      ./result/sw/bin/darwin-rebuild switch --flake .#
    else
      darwin-rebuild switch --flake .#
    fi
  fi
}

# Main installation
main() {
  log_info "Starting installation..."

  # Check requirements
  check_requirements

  # Install and configure Nix
  install_nix
  configure_nix
  add_nix_channels

  # Setup based on OS
  if [ "$(detect_os)" = "darwin" ]; then
    # Setup nix-darwin (which includes home-manager)
    setup_darwin
  else
    # Setup home-manager
    setup_home_manager
  fi

  log_info "Installation completed successfully!"
  log_warn "Please restart your shell or source your profile"
}

# Run main function
main
