# Install Rex support without taking ownership of the Stow-managed config files.
{ inputs, ... }:
let
  profileSupport = {
    # useUserPackages adds an outer OS profile around Home Manager's environment.
    # Both Darwin and NixOS filter share/ here, even though HM links everything.
    environment.pathsToLink = [ "/share/rexpick" ];
  };
in
{
  flake.modules = {
    darwin.rex = profileSupport;
    nixos.rex = profileSupport;

    homeManager.rex =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.programs.rex;
      in
      {
        imports = [ inputs.rex.homeManagerModules.default ];

        programs.rex = {
          enable = true;
          config = null; # home/.config/rex/init.lua
          sshGuard = false; # home/.ssh/config includes home/.config/rex/ssh_config
        };

        # No services.rex: the macOS app owns its server. Linux service enablement
        # is a separate host decision, not a side effect of installing the CLI.
        home.packages = [ pkgs.rexpick ];

        # Install Rex's agent skill and hooks with session naming off. Agents
        # renamed sessions after their task whenever the hook asked, even with a
        # rule against it in AGENTS.md, overwriting the project label the picker
        # sets. The stub and hooks live in ~/.agents, ~/.claude and ~/.codex
        # outside any repo, so setup reruns on every switch; it leaves matching
        # files alone. Runs after both stows so it writes through the
        # ~/.claude/skills link that nix-private owns instead of shadowing it.
        #
        # Rex is in closed beta and may be missing (package = null, or a machine
        # without the download), so a missing CLI or a failed setup only warns.
        home.activation.rexAgentSkill =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "stowHome"
              "stowPrivateHome"
            ]
            ''
              rex_bin=${lib.optionalString (cfg.package != null) (lib.getExe' cfg.package "rex")}
              if [ ! -x "$rex_bin" ]; then
                rex_bin=$(command -v rex || true)
              fi

              if [ -z "$rex_bin" ]; then
                verboseEcho "rex: CLI not found, skipping agent skill setup"
              elif [[ -v DRY_RUN ]]; then
                echo "$rex_bin" skill setup --session-naming=false
              elif ! rex_out=$("$rex_bin" skill setup --session-naming=false --json 2>&1); then
                warnEcho "rex: agent skill setup failed, existing skill and hooks left as they were"
                echo "$rex_out"
              else
                rex_changes=$(${lib.getExe pkgs.jq} -r \
                  '.steps[] | select(.change != "unchanged" and .change != "skipped") | "  \(.kind) \(.change): \(.path)"' \
                  <<<"$rex_out" || true)
                if [ -n "$rex_changes" ]; then
                  noteEcho "rex: updated agent skill and hooks"
                  echo "$rex_changes"
                  if [[ $rex_changes == *.codex/hooks.json* ]]; then
                    noteEcho "rex: approve the changed hook with /hooks in Codex"
                  fi
                fi
              fi
            '';
      };
  };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      checks = lib.optionalAttrs (builtins.hasAttr system inputs.rex.packages) {
        rex-project-picker-config = pkgs.callPackage ../../pkgs/rex-project-picker/tests/config.nix {
          inherit (inputs.rex.packages.${system}) rex;
        };
      };
    };
}
