# Yabai tiling window manager
_: {
  flake.modules.darwin.yabai =
    { pkgs, ... }:
    {
      services.yabai = {
        enable = true;
        enableScriptingAddition = true;
        package = pkgs.yabai;
      };

      # For yabai debugging
      launchd.user.agents.yabai.serviceConfig.StandardErrorPath = "/tmp/yabai.err.log";
      launchd.user.agents.yabai.serviceConfig.StandardOutPath = "/tmp/yabai.out.log";
    };
}
