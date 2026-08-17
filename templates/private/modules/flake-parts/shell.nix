_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShellNoCC {
        name = "private-shell";

        packages = [
          # From the upstream's overlays, so whatever it does to clan-cli
          # applies here too. See docs/upstream-contract.md.
          pkgs.clan-cli

          pkgs.sops
          pkgs.age
          pkgs.ssh-to-age
          config.treefmt.build.wrapper
        ];

        shellHook = ''
          # Same key .sops.yaml lists as the admin recipient
          if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
            SOPS_AGE_KEY=$(ssh-to-age -private-key < "$HOME/.ssh/id_ed25519" 2>/dev/null) || true
            export SOPS_AGE_KEY
          fi
        '';
      };
    };
}
