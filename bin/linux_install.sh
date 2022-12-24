#!/bin/bash
# First install nix.
if ! type nix &> /dev/null
then
    echo "Installing nix..."
    curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh
    sh /tmp/nix-install.sh --daemon
    sh /etc/profile
fi

# Add appropriate nix.conf extras
if ! grep -q "experimental-features" /etc/nix/nix.conf; then
    echo "Adding nix experimental features"
    sudo sed -i '1s/^/experimental-features = nix-command flakes/' /etc/nix/nix.conf
fi

# Now, add nix and home-manager channels.
if ! (echo $(nix-channel --list) | grep -q "nixpkgs"); then
    echo "Add nixpkgs unstable channel"
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
fi
if ! (echo $(nix-channel --list) | grep -q "home-manager"); then
    echo "Add home-manager channel"
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
fi
nix-channel --update

# Install home-manager
if ! type home-manager &> /dev/null; then
    echo "Installing home-manager"
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    nix-shell '<home-manager>' -A install
fi

# Finally, build generate for host
echo "Generating home-manager generation."
home-manager switch --flake .#$USER@$(hostname)
