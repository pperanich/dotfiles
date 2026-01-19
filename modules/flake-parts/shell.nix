{
  perSystem =
    {
      config,
      inputs',
      lib,
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

          inputs'.clan-core.packages.clan-cli
          inputs'.home-manager.packages.home-manager

          # treefmt with config defined in fmt.nix
          config.treefmt.build.wrapper
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          pkgs.age-plugin-se # Secure Enclave plugin - only works on macOS, requires Swift to build
        ];
      };
    };
}
