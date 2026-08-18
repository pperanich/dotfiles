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
          # Activation: `nh os switch .` / `nh darwin switch .`. It elevates
          # itself, shows a build diff, and takes --target-host for a remote.
          pkgs.nh

          # Secrets
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

          # So `nh os switch` with no argument means this repo
          export NH_FLAKE="$PWD"
        '';
      };
    };
}
