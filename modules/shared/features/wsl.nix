# WSL feature module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.wsl;
in {
  options.my.features.wsl = {
    enable = lib.mkEnableOption "Windows Subsystem for Linux configuration";

    defaultUser = lib.mkOption {
      type = lib.types.str;
      description = "Default user for WSL";
    };

    startMenuLaunchers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable start menu launchers";
    };

    nativeSystemd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable native systemd support";
    };
  };

  config = lib.mkIf cfg.enable {
    wsl = {
      enable = true;
      inherit (cfg) defaultUser;
      inherit (cfg) startMenuLaunchers;
      inherit (cfg) nativeSystemd;

      # WSL-specific settings
      wslConf = {
        automount.root = "/mnt";
        network.generateResolvConf = true;
      };
    };

    # WSL-specific system configuration
    system.stateVersion = lib.mkDefault "23.11";
  };
}
