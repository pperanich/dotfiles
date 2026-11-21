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

    nixos.rex =
      { config, lib, ... }:
      let
        cfg = config.my.rex.loginServer;
      in
      {
        imports = [ inputs.rex.nixosModules.default ];

        options.my.rex.loginServer = {
          enable = lib.mkEnableOption "the Rex login server on this host's tailnet addresses";

          port = lib.mkOption {
            type = lib.types.port;
            default = 7297;
            description = "Tailnet TCP port of the Rex login server. Clients connect to `http://<host>.<tailnet>:<port>`.";
          };

          principals = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ "tailscale:tag:admin" ];
            example = [
              "tailscale:tag:admin"
              "tailscale:tag:mobile"
            ];
            description = "Tailnet identities this host admits. User modules map them to their account; the tailnet ACL must also let them reach the port.";
          };
        };

        config = lib.mkMerge [
          profileSupport
          (lib.mkIf cfg.enable {
            services.rex.loginServer = {
              enable = true;
              # Headscale issues no tailnet certificates and Serve hides tagged callers,
              # so the listener is plain HTTP inside WireGuard. User modules add accounts.
              extraListen = [ "tailnet://:${toString cfg.port}" ];
            };

            # A deploy that restarts tailscaled starts this before tailnet addresses return, and the
            # failed first bind fails the activation. Upstream gates its Serve unit the same way.
            systemd.services.rex-login-server.serviceConfig.ExecStartPre =
              "${lib.getExe config.services.tailscale.package} wait";

            networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
              cfg.port
            ];
          })
        ];
      };

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

        # No user service: the login server or `rex -S ssh://host` starts the account's
        # server on demand, and a unit on the same socket loses the race to it.
        home.packages = [ pkgs.rexpick ];

        # Install Rex's agent skill and hooks with session naming off. Agents
        # renamed sessions after their task whenever the hook asked, even with a
        # rule against it in AGENTS.md, overwriting the project label the picker
        # sets. The stub and hooks live in ~/.agents, ~/.claude and ~/.codex
        # outside any repo, so setup reruns on every switch; it leaves matching
        # files alone. Runs after both stows, which lay out ~/.agents/skills and
        # ~/.claude/skills as real directories, so its skill lands beside the
        # stowed links and never inside a checkout.
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
