# Development shell configuration
{pkgs, ...}:
pkgs.mkShell {
  name = "dotfiles-shell";

  NIX_CONFIG = "extra-experimental-features = nix-command flakes ca-derivations";

  nativeBuildInputs = with pkgs; [
    # Nix tools
    nix
    home-manager
    alejandra

    # System tools
    git

    # Secret management
    sops
    ssh-to-age
    gnupg
    age
  ];

  shellHook = ''
    echo "Welcome to the dotfiles development shell!"
    echo "Available flake outputs:"
    echo " - nixosConfigurations"
    echo " - darwinConfigurations"
    echo " - homeConfigurations"
  '';
}
