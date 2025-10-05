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

        packages = [
          # Secret management
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.gnupg
          pkgs.age
          pkgs.age-plugin-se

          inputs'.clan-core.packages.clan-cli

          # treefmt with config defined in fmt.nix
          config.treefmt.build.wrapper
        ];
      };
    };
}
