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

ask_yes_no() {
  local reply
  if [ "$opt_assume_yes" = true ]; then
    return 0
  fi
  if ! have_tty; then
    return 1
  fi
  printf '%s%s%s [y/N] ' "$C_BOLD" "$1" "$C_RESET" >/dev/tty
  read -r reply </dev/tty || reply=""
  case "$reply" in
  [yY] | [yY][eE][sS]) return 0 ;;
  *) return 1 ;;
  esac
}

# A "no" here ends the run; use ask_yes_no for optional steps.
confirm() {
  if ask_yes_no "$1"; then
    return 0
  fi
  if [ "$opt_assume_yes" != true ] && ! have_tty; then
    log_error "no terminal available to confirm; re-run with --yes"
    exit 1
  fi
  log_info "aborted"
  exit 0
}

# Ask on the tty, echo the reply on stdout, fall back to $2 when it is empty.
prompt_value() {
  local question="$1" default="$2" reply
  printf '%s%s%s [%s] ' "$C_BOLD" "$question" "$C_RESET" "$default" >/dev/tty
  read -r reply </dev/tty || reply=""
  if [ -z "$reply" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$reply"
  fi
}

tmp_dir() {
  if [ -z "$TMP_DIR" ]; then
    TMP_DIR="$(mktemp -d)"
  fi
  printf '%s\n' "$TMP_DIR"
}

# `sed -i` requires an argument on BSD and refuses one on GNU; sidestep it.
sed_inplace() {
  local script="$1" file="$2" tmp
  tmp="$(tmp_dir)/sed.out"
  sed "$script" "$file" >"$tmp"
  cat "$tmp" >"$file"
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

target_output() {
  case "$opt_mode" in
  darwin) printf 'darwinConfigurations\n' ;;
  nixos) printf 'nixosConfigurations\n' ;;
  home) printf 'homeConfigurations\n' ;;
  esac
}

# Catch a missing configuration here rather than several minutes into nix
# evaluation. Someone running this against a flake whose machines are not
# theirs gets offered the template instead of a dead end.
resolve_flake_target() {
  local output target names
  output="$(target_output)"
  target="$opt_host"
  if [ "$opt_mode" = home ]; then
    target="${opt_host:-$USER}"
  fi

  names="$(flake_attr_names "$output")"
  if [ -z "$names" ]; then
    return 0
  fi
  if printf '%s\n' "$names" | grep -Fxq "$target"; then
    return 0
  fi

  log_warn "no ${output}.${target} in this flake"
  log_warn "available: $(printf '%s' "$names" | tr '\n' ' ')"

  if [ "$opt_assume_yes" = true ] || ! have_tty; then
    log_error "nothing here matches this machine"
    log_error "pass --host with one of the names above, or run interactively to"
    log_error "scaffold your own configuration from this flake's template"
    exit 1
  fi

  offer_template "$names"
}

offer_template() {
  local names="$1" choice
  cat >/dev/tty <<'EOF'

These machines belong to the flake's author. You can start your own
configuration from the template it ships, or switch to one of its hosts.

  1) Scaffold my own configuration from the dendritic template
  2) Use one of the hosts listed above
  3) Quit

EOF
  choice="$(prompt_value "Choice" "1")"
  case "$choice" in
  1) scaffold_template ;;
  2) pick_existing_target "$names" ;;
  *)
    log_info "aborted"
    exit 0
    ;;
  esac
}

pick_existing_target() {
  local names="$1" first pick
  first="$(printf '%s\n' "$names" | head -1)"
  pick="$(prompt_value "Name" "$first")"
  if ! printf '%s\n' "$names" | grep -Fxq "$pick"; then
    log_error "not one of: $(printf '%s' "$names" | tr '\n' ' ')"
    exit 1
  fi
  opt_host="$pick"
}

template_platform() {
  case "${OS}-$(uname -m)" in
  darwin-arm64) printf 'aarch64-darwin\n' ;;
  darwin-x86_64) printf 'x86_64-darwin\n' ;;
  linux-x86_64) printf 'x86_64-linux\n' ;;
  linux-aarch64 | linux-arm64) printf 'aarch64-linux\n' ;;
  esac
}

# The template's `example` user is referenced from seven places. A blanket
# substitution would also rewrite the illustrative comments in lib/ and
# overlays/, so each site is handled by name.
template_rename_user() {
  local dir="$1" user="$2" cfg
  if [ "$user" = example ]; then
    return 0
  fi

  mv "$dir/modules/users/example.nix" "$dir/modules/users/${user}.nix"
  mv "$dir/home-profiles/example" "$dir/home-profiles/${user}"

  local module="$dir/modules/users/${user}.nix"
  # The rename checklist at the top of the module is what we just carried out.
  sed_inplace '/^# Rename checklist when you make this your own:/,/^#   4\./d' "$module"
  sed_inplace "s|username = \"example\";|username = \"${user}\";|" "$module"
  sed_inplace "s|home-profiles/example|home-profiles/${user}|g" "$module"

  local profile="$dir/home-profiles/${user}/default.nix"
  sed_inplace "s|home.username = \"example\";|home.username = \"${user}\";|" "$profile"
  sed_inplace "s|homeConfigurations.example|homeConfigurations.${user}|" "$profile"
  sed_inplace "s|home-manager.users.example|home-manager.users.${user}|" "$profile"
  sed_inplace "s|modules/users/example.nix|modules/users/${user}.nix|" "$profile"

  sed_inplace "s|^  example: |  ${user}: |" "$dir/sops/secrets.yaml"
  sed_inplace "s|for the example user|for the ${user} user|" "$dir/sops/secrets.yaml"
  sed_inplace "s|\.#example|.#${user}|" "$dir/modules/flake-parts/home.nix"
  sed_inplace "s|modules/users/example.nix|modules/users/${user}.nix|" \
    "$dir/modules/system/sops.nix"

  for cfg in "$dir"/machines/*/*/configuration.nix; do
    if [ -e "$cfg" ]; then
      sed_inplace "s|^    example$|    ${user}|" "$cfg"
    fi
  done
}

template_rename_machine() {
  local dir="$1" class="$2" host="$3" platform="$4" other=darwin
  if [ "$class" = darwin ]; then
    other=nixos
  fi

  mv "$dir/machines/${class}/example-${class}" "$dir/machines/${class}/${host}"
  rm -rf "$dir/machines/${other}"

  local cfg="$dir/machines/${class}/${host}/configuration.nix"
  sed_inplace "s|networking.hostName = \"example-${class}\";|networking.hostName = \"${host}\";|" "$cfg"
  sed_inplace "s|nixpkgs.hostPlatform = \".*\";|nixpkgs.hostPlatform = \"${platform}\";|" "$cfg"

  # Keep this host's age recipient placeholder, drop the other class's.
  sed_inplace "s|&example-${class}|\\&${host}|" "$dir/sops/.sops.yaml"
  sed_inplace "s|\\*example-${class}|*${host}|" "$dir/sops/.sops.yaml"
  sed_inplace "/example-${other}/d" "$dir/sops/.sops.yaml"

  # homeConfigurations are not per-system, so the template pins one. Point it
  # at this machine, or standalone home-manager builds for the wrong platform.
  sed_inplace "s|withSystem \"x86_64-linux\"|withSystem \"${platform}\"|" \
    "$dir/modules/flake-parts/home.nix"
}

# --- secrets bootstrap ----------------------------------------------------

SOPS_BIN=""
SSH_TO_AGE_BIN=""
MKPASSWD_BIN=""
SECRET_PASSWORD=""
SECRET_PASSWORD_GENERATED=false

# `nix build --print-out-paths` lists every output of a package and -man can
# sort first, so pick whichever one actually carries the binary.
nix_bin() {
  local pkg="$1" bin="$2" paths path
  paths="$(nix build --no-link --print-out-paths "nixpkgs#${pkg}" 2>/dev/null || true)"
  while IFS= read -r path; do
    if [ -n "$path" ] && [ -x "$path/bin/$bin" ]; then
      printf '%s/bin/%s\n' "$path" "$bin"
      return 0
    fi
  done <<EOF
$paths
EOF
}

fetch_secret_tools() {
  log_step "Building sops, ssh-to-age and mkpasswd"
  SOPS_BIN="$(nix_bin sops sops)"
  SSH_TO_AGE_BIN="$(nix_bin ssh-to-age ssh-to-age)"
  MKPASSWD_BIN="$(nix_bin mkpasswd mkpasswd)"
  if [ -z "$SOPS_BIN" ] || [ -z "$SSH_TO_AGE_BIN" ] || [ -z "$MKPASSWD_BIN" ]; then
    log_error "could not build sops, ssh-to-age and mkpasswd from nixpkgs"
    return 1
  fi
}

# sops-nix reads the user's key unattended at activation, so a passphrase makes
# it unusable. -P '' fails immediately instead of prompting.
key_is_usable() {
  ssh-keygen -y -P '' -f "$1" >/dev/null 2>&1
}

list_ed25519_keys() {
  local pub priv
  for pub in "$HOME"/.ssh/*.pub; do
    [ -e "$pub" ] || continue
    priv="${pub%.pub}"
    [ -f "$priv" ] || continue
    if grep -q '^ssh-ed25519 ' "$pub"; then
      printf '%s\n' "$priv"
    fi
  done
}

# Echo the chosen private key path; prompts and progress go elsewhere so this
# stays usable inside $(...).
choose_ssh_key() {
  local keys priv pick n=0 total label default_new
  keys="$(list_ed25519_keys)"

  {
    printf '\n'
    if [ -n "$keys" ]; then
      printf 'ed25519 keys in ~/.ssh:\n\n'
      while IFS= read -r priv; do
        [ -n "$priv" ] || continue
        n=$((n + 1))
        if key_is_usable "$priv"; then
          label="no passphrase"
        else
          label="passphrase-protected, cannot be used unattended"
        fi
        printf '  %d) %s  (%s)\n' "$n" "$priv" "$label"
      done <<KEYS
$keys
KEYS
    fi
    n=$((n + 1))
    printf '  %d) generate a new key for this configuration\n\n' "$n"
    printf 'Picking an existing key copies its private half into\n'
    printf 'sops/secrets.yaml (encrypted, committed) and deploys it to every\n'
    printf 'host importing the user module.\n\n'
  } >/dev/tty
  total="$n"

  pick="$(prompt_value "Key" "$total")"
  case "$pick" in
  '' | *[!0-9]*)
    log_error "not a number: $pick"
    return 0
    ;;
  esac
  if [ "$pick" -lt 1 ] || [ "$pick" -gt "$total" ]; then
    log_error "choice out of range: $pick"
    return 0
  fi

  if [ "$pick" -eq "$total" ]; then
    default_new="$HOME/.ssh/id_ed25519"
    if [ -e "$default_new" ]; then
      default_new="$HOME/.ssh/id_ed25519_nixcfg"
    fi
    priv="$(prompt_value "New key path" "$default_new")"
    if [ -e "$priv" ]; then
      log_error "$priv already exists"
      return 0
    fi
    mkdir -p "$(dirname "$priv")"
    chmod 700 "$(dirname "$priv")"
    # ssh-keygen chatters on stdout, which this function reserves for the path.
    ssh-keygen -t ed25519 -N '' -C "${USER}@$(uname -n)" -f "$priv" -q 1>&2
    printf '%s\n' "$priv"
    return 0
  fi

  priv="$(printf '%s\n' "$keys" | sed -n "${pick}p")"
  if [ -z "$priv" ]; then
    log_error "no key at choice $pick"
    return 0
  fi
  if ! key_is_usable "$priv"; then
    log_error "$priv is passphrase-protected, so sops-nix cannot read it"
    log_error "pick another key or generate a new one"
    return 0
  fi
  printf '%s\n' "$priv"
}

random_password() {
  LC_ALL=C dd if=/dev/urandom bs=1 count=256 2>/dev/null |
    LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-24
}

# Sets SECRET_PASSWORD and SECRET_PASSWORD_GENERATED.
choose_password() {
  local p1 p2
  printf '%sLogin password%s (blank generates one): ' "$C_BOLD" "$C_RESET" >/dev/tty
  read -rs p1 </dev/tty || p1=""
  printf '\n' >/dev/tty

  if [ -z "$p1" ]; then
    SECRET_PASSWORD="$(random_password)"
    SECRET_PASSWORD_GENERATED=true
    if [ -z "$SECRET_PASSWORD" ]; then
      log_error "could not generate a password"
      return 1
    fi
    return 0
  fi

  printf '%sConfirm%s: ' "$C_BOLD" "$C_RESET" >/dev/tty
  read -rs p2 </dev/tty || p2=""
  printf '\n' >/dev/tty
  if [ "$p1" != "$p2" ]; then
    log_error "passwords did not match"
    return 1
  fi
  SECRET_PASSWORD="$p1"
  SECRET_PASSWORD_GENERATED=false
}

host_age_recipient() {
  local pub=/etc/ssh/ssh_host_ed25519_key.pub
  if [ ! -e "$pub" ]; then
    log_warn "no $pub, so this machine has no SSH host key yet"
    log_warn "without it sops-nix cannot decrypt system secrets at activation"
    if ask_yes_no "Generate a host key now (needs sudo)?"; then
      sudo_preflight
      sudo ssh-keygen -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key -q 1>&2
    fi
  fi
  if [ -e "$pub" ]; then
    "$SSH_TO_AGE_BIN" -i "$pub" 2>/dev/null || true
  fi
}

# Fills in real age recipients, a password hash and the user's private key,
# then encrypts. Returns non-zero without leaving plaintext behind.
bootstrap_secrets() {
  local dir="$1" user="$2" host="$3"
  local key admin_age host_age hash secrets identity age_dir age_file

  fetch_secret_tools || return 1

  key="$(choose_ssh_key)"
  if [ -z "$key" ]; then
    return 1
  fi
  log_info "using $key"

  admin_age="$("$SSH_TO_AGE_BIN" -i "${key}.pub" 2>/dev/null || true)"
  case "$admin_age" in
  age1*) ;;
  *)
    log_error "could not derive an age recipient from ${key}.pub"
    return 1
    ;;
  esac

  host_age="$(host_age_recipient)"

  choose_password || return 1
  hash="$(printf '%s\n' "$SECRET_PASSWORD" | "$MKPASSWD_BIN" -m sha-512 -s 2>/dev/null || true)"
  # A sha-512 crypt hash starts with a literal $6$
  if [ "${hash#\$6\$}" = "$hash" ]; then
    log_error "mkpasswd did not return a sha-512 hash"
    return 1
  fi

  log_step "Writing age recipients into sops/.sops.yaml"
  sed_inplace "s|^  - &admin age1REPLACEME.*|  - \\&admin ${admin_age}|" "$dir/sops/.sops.yaml"
  if [ -n "$host_age" ]; then
    sed_inplace "s|^  - &${host} age1REPLACEME.*|  - \\&${host} ${host_age}|" "$dir/sops/.sops.yaml"
  fi

  secrets="$dir/sops/secrets.yaml"
  : >"$secrets"
  chmod 600 "$secrets"
  {
    printf 'passwords:\n'
    printf '  %s: "%s"\n' "$user" "$hash"
    printf 'private_keys:\n'
    printf '  %s: |\n' "$user"
    sed 's/^/    /' "$key"
    printf 'api_keys:\n'
    printf '  openai: REPLACE_ME\n'
  } >"$secrets"

  log_step "Encrypting sops/secrets.yaml"
  if ! (cd "$dir" && "$SOPS_BIN" -e -i sops/secrets.yaml); then
    rm -f "$secrets"
    log_error "sops failed to encrypt; removed the plaintext secrets file"
    return 1
  fi
  if ! grep -q 'ENC\[' "$secrets"; then
    rm -f "$secrets"
    log_error "sops reported success but wrote no ciphertext; removed the file"
    return 1
  fi
  chmod 644 "$secrets"

  # So `sops sops/secrets.yaml` works outside `nix develop` too. Append rather
  # than overwrite: this file may already hold other identities.
  identity="$("$SSH_TO_AGE_BIN" -private-key -i "$key" 2>/dev/null || true)"
  if [ -n "$identity" ]; then
    age_dir="$HOME/.config/sops/age"
    age_file="$age_dir/keys.txt"
    mkdir -p "$age_dir"
    chmod 700 "$age_dir"
    if [ -e "$age_file" ]; then
      if ! grep -qF "$identity" "$age_file"; then
        printf '%s\n' "$identity" >>"$age_file"
      fi
    else
      printf '%s\n' "$identity" >"$age_file"
      chmod 600 "$age_file"
    fi
    log_info "age identity available in $age_file"
  fi

  if [ -n "$host_age" ]; then
    sed_inplace "s|validateSopsFiles = lib.mkDefault false;|validateSopsFiles = lib.mkDefault true;|" \
      "$dir/modules/system/sops.nix"
  else
    log_warn "left validateSopsFiles = false: add this host's recipient to"
    log_warn "sops/.sops.yaml, run 'sops updatekeys sops/secrets.yaml', then enable it"
  fi
}

template_next_steps() {
  local dir="$1" class="$2" host="$3" user="$4" secrets_ready="$5" n=1
  printf '\n'
  printf "Scaffolded into %s, with machine '%s' and user '%s'.\n\n" "$dir" "$host" "$user"

  if [ "$secrets_ready" != true ]; then
    cat <<EOF
sops/secrets.yaml is still the shipped placeholder, so nothing can be
switched yet: activation fails until real secrets exist.

EOF
  fi

  printf 'Remaining steps:\n'
  printf '  %d. cd %s && nix develop && nix flake check\n' "$n" "$dir"
  n=$((n + 1))
  if [ "$class" = nixos ]; then
    printf '  %d. nixos-generate-config --show-hardware-config \\\n' "$n"
    printf '       > machines/%s/%s/hardware-configuration.nix\n' "$class" "$host"
    n=$((n + 1))
  fi
  if [ "$secrets_ready" != true ]; then
    printf '  %d. follow docs/sops.md, then set validateSopsFiles = true\n' "$n"
    n=$((n + 1))
  fi
  if [ "$class" = nixos ]; then
    printf '  %d. sudo nixos-rebuild switch --flake .#%s\n' "$n" "$host"
  else
    printf '  %d. darwin-rebuild switch --flake .#%s\n' "$n" "$host"
  fi
  printf '\n'

  if [ "$SECRET_PASSWORD_GENERATED" = true ] && [ -n "$SECRET_PASSWORD" ]; then
    printf '  %sGenerated login password: %s%s\n' "$C_BOLD" "$SECRET_PASSWORD" "$C_RESET"
    printf '  Record it now. Only the hash is stored, so it cannot be recovered.\n\n'
  fi
}

scaffold_template() {
  local dir user host class platform
  class=darwin
  if [ "$OS" = linux ]; then
    class=nixos
  fi
  platform="$(template_platform)"
  if [ -z "$platform" ]; then
    log_error "no template platform for $(uname -s) $(uname -m)"
    exit 1
  fi

  dir="$(prompt_value "New configuration directory" "$HOME/nix-config")"
  user="$(prompt_value "Primary username" "$USER")"
  host="$(prompt_value "Name for this machine" "${HOSTNAME_DETECTED:-my-${class}}")"

  if [ -e "$dir/flake.nix" ]; then
    log_error "$dir already contains a flake.nix"
    exit 1
  fi

  printf '\n'
  printf '  %-10s %s\n' "Directory" "$dir"
  printf '  %-10s %s\n' "User" "$user"
  printf '  %-10s %s (%s)\n' "Machine" "$host" "$platform"
  printf '  %-10s %s\n' "Template" "${FLAKE_DIR}#dendritic"
  printf '\n'
  confirm "Scaffold this configuration?"

  # Swallow the template's own welcome text: it lists steps this script then
  # performs. Keep the output for the failure case.
  log_step "Writing the template into $dir"
  local out
  out="$(tmp_dir)/flake-new.log"
  if ! nix flake new -t "${FLAKE_DIR}#dendritic" "$dir" >"$out" 2>&1; then
    cat "$out" >&2
    log_error "nix flake new failed"
    exit 1
  fi

  log_step "Renaming the example user and machine"
  template_rename_user "$dir" "$user"
  template_rename_machine "$dir" "$class" "$host" "$platform"

  local secrets_ready=false
  printf '\n'
  printf 'Secrets can be bootstrapped now: an age recipient from an ed25519 SSH\n'
  printf 'key, a password hash, and an encrypted sops/secrets.yaml.\n'
  if ask_yes_no "Bootstrap secrets?"; then
    if bootstrap_secrets "$dir" "$user" "$host"; then
      secrets_ready=true
    else
      log_warn "secrets bootstrap did not complete; nothing encrypted was written"
    fi
  fi

  # After the secrets step, so a plaintext secrets.yaml can never be staged.
  log_step "Initialising git, since flakes only see tracked files"
  git -C "$dir" init --quiet
  git -C "$dir" add -A

  template_next_steps "$dir" "$class" "$host" "$user" "$secrets_ready"
  unset SECRET_PASSWORD
  exit 0
}

switch_darwin() {
  local host="$1"

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

  # This flake pins homeConfigurations to a single system; refuse early rather
  # than fail deep in the build on a mismatched host.
  local want have
  want="$(nix eval --raw \
    "${FLAKE_DIR}#homeConfigurations.${user}.pkgs.stdenv.hostPlatform.system" 2>/dev/null || true)"
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

If the flake has no configuration for this machine, an interactive run offers
to scaffold your own from the dendritic template instead, and can bootstrap
secrets: an age recipient from an ed25519 SSH key (existing or freshly
generated), a sha-512 password hash, and an encrypted sops/secrets.yaml.
With --yes, or with no terminal, it lists the valid names and exits.
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
  resolve_flake_target
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
