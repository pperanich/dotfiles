{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      devShells.default = pkgs.mkShellNoCC {
        name = "private-shell";

        packages = [
          # pkgs, not inputs.clan-core.packages: pkgs carries the upstream's
          # overlays, so any override it applies to clan-cli (a different nix
          # in the wrapper, say) is inherited rather than re-solved here. Falls
          # back to the plain package when the upstream does not override it.
          (pkgs.clan-cli or inputs.clan-core.packages.${system}.clan-cli)

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
