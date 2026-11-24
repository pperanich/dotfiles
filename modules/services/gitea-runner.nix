# Gitea Actions runner registered against the self-hosted Gitea. Docker labels
# run jobs under the host's own dockerd; `native:host` runs them on the host.
_: {
  flake.modules.nixos.giteaRunner =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.my.giteaRunner;
      instanceName = config.networking.hostName;
      unitName = "gitea-runner-${utils.escapeSystemdPath instanceName}.service";
    in
    {
      options.my.giteaRunner = {
        enable = lib.mkEnableOption "Gitea Actions runner";

        url = lib.mkOption {
          type = lib.types.str;
          example = "https://gitea.example.com";
          description = "Base URL of the Gitea instance the runner registers with.";
        };

        tokenSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "gitea-runner-token";
          description = "sops key holding the runner registration token.";
        };

        labels = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"
            "ubuntu-24.04:docker://docker.gitea.com/runner-images:ubuntu-24.04"
            "native:host"
          ];
          description = ''
            Runner labels mapping `runs-on` values to an execution environment.
            Changing them makes the runner re-register on next start.
          '';
        };

        capacity = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1;
          description = "Maximum number of concurrent jobs the runner will execute.";
        };

        envs = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Extra environment variables injected into every job.";
        };

        containerPrivileged = lib.mkEnableOption "privileged mode for Docker job containers (needed for --device /dev/kvm)";

        containerOptions = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "--device /dev/kvm --volume /var/cache/ci:/cache/ci";
          description = "Extra Docker CLI options passed when launching job containers.";
        };

        validVolumes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "/var/cache/ci" ];
          description = "Host paths or volume globs job containers are permitted to mount.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.tokenSecret != null;
            message = "my.giteaRunner.tokenSecret is unset; the runner cannot register with Gitea.";
          }
        ];

        sops = lib.mkIf (cfg.tokenSecret != null) {
          secrets.${cfg.tokenSecret} = { };
          templates."gitea-runner.env" = {
            content = "TOKEN=${config.sops.placeholder.${cfg.tokenSecret}}";
            restartUnits = [ unitName ];
          };
        };

        virtualisation.docker.enable = true;

        services.gitea-actions-runner.instances.${instanceName} = {
          enable = true;
          name = instanceName;
          inherit (cfg) url labels;
          settings = {
            runner = {
              inherit (cfg) capacity;
            }
            // lib.optionalAttrs (cfg.envs != { }) {
              inherit (cfg) envs;
            };
            container =
              lib.optionalAttrs cfg.containerPrivileged {
                privileged = true;
              }
              // lib.optionalAttrs (cfg.containerOptions != null) {
                options = cfg.containerOptions;
              }
              // lib.optionalAttrs (cfg.validVolumes != [ ]) {
                valid_volumes = cfg.validVolumes;
              };
          };
          tokenFile = lib.mkIf (cfg.tokenSecret != null) config.sops.templates."gitea-runner.env".path;
          # Upstream defaults plus nix, so `native:host` jobs can run `nix build`.
          hostPackages = with pkgs; [
            bash
            coreutils
            curl
            gawk
            git-pages-cli
            gitMinimal
            gnused
            nix
            nodejs
            wget
          ];
        };
      };
    };
}
