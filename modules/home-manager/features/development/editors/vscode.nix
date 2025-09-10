# VSCode editor configuration
{
  config,
  lib,
  ...
}: let
  cfg = config.my.home.features.development.editors;
in {
  config = lib.mkIf (cfg.enable && cfg.vscode.enable) {
    programs.vscode = {
      enable = true;
    };
  };
}
