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
          # clan-core is not optional here the way it is in the dendritic
          # template: this repo exists to deploy a clan.
          inputs.clan-core.packages.${system}.clan-cli

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
