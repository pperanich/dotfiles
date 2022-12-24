# First install nix.
if ! command -v nix &> /dev/null
then
    curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh
    sh /tmp/nix-install.sh --daemon
    /etc/profile.d/nix.sh
fi

# Add appropriate nix.conf extras
if ! grep -q experimental-features /etc/nix/nix.conf; then
    sudo sed -i '1s/^/experimental-features = nix-command flakes/' /etc/nix/nix.conf
fi

# Now, add nix and home-manager channels.
if ! grep -q nixpkgs $(nix-channel --list); then
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
fi
if ! grep -q home-manager $(nix-channel --list); then
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
fi
nix-channel --update

# Install home-manager
if ! command -v home-manager &> /dev/null
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    nix-shell '<home-manager>' -A install
then

# Finally, build generate for host
home-manager switch --flake .#$USER@$(hostname)
