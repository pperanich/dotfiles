{
  perSystem =
    {
      config,
      inputs',
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShellNoCC {
        name = "dotfiles-shell";

        NIX_CONFIG = "extra-experimental-features = nix-command flakes";
        packages = [
          # Nix tools
          pkgs.nix
          pkgs.home-manager
          pkgs.alejandra

          # System tools
          pkgs.git

          # Secret management
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.gnupg
          pkgs.age
          pkgs.age-plugin-se

          pkgs.nixVersions.latest

          inputs'.clan-core.packages.clan-cli

          # treefmt with config defined in fmt.nix
          config.treefmt.build.wrapper
        ];
        shellHook = ''
          echo "Welcome to the dotfiles development shell!"
          echo "Available flake outputs:"
          echo " - nixosConfigurations"
          echo " - darwinConfigurations"
          echo " - homeConfigurations"
        '';
      };
    };
}
