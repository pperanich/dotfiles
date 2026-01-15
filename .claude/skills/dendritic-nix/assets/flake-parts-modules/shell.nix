# Development shell configuration
# Provides tools and utilities for working with the flake
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShellNoCC {
        name = "dotfiles-shell";

        packages = [
          # Secret management
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.age

          # Nix tools
          pkgs.nix-tree # Explore Nix store dependencies
          pkgs.nix-diff # Compare Nix derivations
          pkgs.nixpkgs-fmt # Nix formatter

          # Optional: Include flake input tools
          # inputs'.home-manager.packages.home-manager
          # inputs'.clan-core.packages.clan-cli

          # Include treefmt wrapper from fmt.nix
          config.treefmt.build.wrapper
        ];

        shellHook = ''
          echo "Development environment loaded"
          echo "Run 'treefmt' to format all files"
        '';
      };
    };
}
