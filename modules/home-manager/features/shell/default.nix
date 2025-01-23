# Shell environment features
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.shell;
in {
  imports = [
    ./tools.nix
    ./zsh.nix
    ./nushell.nix
  ];

  options.modules.home.features.shell = {
    enable = lib.mkEnableOption "shell environment features";

    # Sub-feature toggles
    tools = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable shell tools";
      };
    };

    zsh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Zsh configuration";
      };
    };

    nushell = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Nushell configuration";
      };
    };
  };
}
