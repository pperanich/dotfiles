# First install nix.
sh <(curl -L https://nixos.org/nix/install) --daemon
# Next, trigger login and call nix.
su $USER
# Add appropriate nix.conf extras
sed -i '1s/^/experimental-features = nix-command flakes/' file
# Now, add nix and home-manager channels.
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
# Install home-manager
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
nix-shell '<home-manager>' -A install
# Finally, build generate for host
home-manager switch --flake .#$USER@$HOSTNAME
