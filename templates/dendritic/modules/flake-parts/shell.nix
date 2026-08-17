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
        name = "dendritic-shell";

        packages = [
          # Secrets
          pkgs.sops
          pkgs.age
          pkgs.ssh-to-age

          inputs'.home-manager.packages.home-manager
          config.treefmt.build.wrapper
        ];

        shellHook = ''
          # sops decrypts with an age key derived from your SSH key — same key
          # that .sops.yaml lists as a recipient (see docs/sops.md)
          if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
            SOPS_AGE_KEY=$(ssh-to-age -private-key < "$HOME/.ssh/id_ed25519" 2>/dev/null) || true
            export SOPS_AGE_KEY
          fi
        '';
      };
    };
}
