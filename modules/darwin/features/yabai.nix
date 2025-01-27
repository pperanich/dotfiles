{ 
  config,
  lib,
  pkgs, 
  ... 
}: let
  cfg = config.my.features.yabai;
in {

  options.my.features.yabai = {
    enable = lib.mkEnableOption "Tiling window manager.";
  };

  config = lib.mkIf cfg.enable {
    services = {
        yabai = {
          enable = true;
          enableScriptingAddition = true;
          package = pkgs.yabai;
        };
      };

      # For yabai debugging
      launchd.user.agents.yabai.serviceConfig.StandardErrorPath = "/tmp/yabai.err.log";
      launchd.user.agents.yabai.serviceConfig.StandardOutPath = "/tmp/yabai.out.log";  };
}
