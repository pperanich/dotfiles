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
          pkgs.age-plugin-yubikey
          pkgs.zensical

          # Deployment & activation ergonomics
          pkgs.deploy-rs
          pkgs.nh
          inputs'.home-manager.packages.home-manager

          # treefmt with config defined in fmt.nix
          config.treefmt.build.wrapper

          # Cloudflare CLI (DNS sync + tunnel provisioning)
          # pkgs.cf
          # ]
          # ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          #   pkgs.age-plugin-se # Secure Enclave plugin - only works on macOS, requires Swift to build
        ];

        shellHook = ''
          # sops admin key; the YubiKey also works when plugged in
          export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

          export PATH=$PWD/bin/:$PATH
        '';
      };
    };
}
