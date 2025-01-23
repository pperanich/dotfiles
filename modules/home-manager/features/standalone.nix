# Standalone home-manager configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home;
  homePrefix =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "Users"
    else "home";
in {
  options.modules.home.standalone = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable standalone home-manager configuration";
    };
  };

  config = lib.mkIf cfg.standalone.enable {
    nix = {
      package = pkgs.nix;
      settings = {
        experimental-features = ["nix-command" "flakes"];
        warn-dirty = false;
      };
    };
    targets.genericLinux.enable = true;
    home.homeDirectory = "/${homePrefix}/${config.home.username}";
  };
}
