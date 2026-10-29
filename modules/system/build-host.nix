_: {
  # Clan build host -> target closure copies over a dedicated key, per
  # clan-core docs/src/guides/ssh-agent-forwarding.md.
  flake.modules.nixos.buildHost =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.buildHost;
      keyFile =
        name:
        config.clan.core.settings.directory + "/vars/per-machine/${name}/build-host-key/public-key/value";
    in
    {
      options.my.buildHost = {
        enable = lib.mkEnableOption "a clan-managed SSH key root uses to copy closures to targets";
        trusted = lib.mkOption {
          type = with lib.types; listOf str;
          default = [ ];
          example = [ "pp-wsl1" ];
          description = "Clan machines whose build-host key may log in as root to deploy here.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          clan.core.vars.generators.build-host-key = {
            files.private-key = { };
            files.public-key.secret = false;
            runtimeInputs = [ pkgs.openssh ];
            script = ''
              ssh-keygen -t ed25519 -f "$out/private-key" -N "" -C "buildhost@${config.clan.core.settings.machine.name}"
              mv "$out/private-key.pub" "$out/public-key"
            '';
          };

          # Root only: other users can't read the key and would get a warning.
          # `Match all` closes the block so later extraConfig isn't root-only.
          programs.ssh.extraConfig = ''
            Match localuser root
              IdentityFile ${config.clan.core.vars.generators.build-host-key.files.private-key.path}
            Match all
          '';
        })
        {
          assertions = map (name: {
            assertion = builtins.pathExists (keyFile name);
            message = "my.buildHost.trusted: no build-host key for ${name}; run `clan vars generate ${name}`.";
          }) cfg.trusted;

          users.users.root.openssh.authorizedKeys.keys = map (
            name: lib.trim (builtins.readFile (keyFile name))
          ) (lib.filter (name: builtins.pathExists (keyFile name)) cfg.trusted);
        }
      ];
    };
}
