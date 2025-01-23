# VSCode editor configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.development.editors;
in {
  config = lib.mkIf (cfg.enable && cfg.vscode.enable) {
    programs.vscode = {
      enable = true;
    };
  };
}
