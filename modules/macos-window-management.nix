_: {
  flake.modules.darwin.windowManagement = {pkgs, ...}: {
    services = {
      # Yabai - Tiling window manager
      yabai = {
        enable = true;
        enableScriptingAddition = true;
        package = pkgs.yabai;
      };

      # Sketchybar - Status bar
      sketchybar = {
        enable = true;
        package = pkgs.sketchybar;
        extraPackages = [
          pkgs.switchaudio-osx
        ];
      };

      # skhd - Simple hotkey daemon
      skhd = {
        enable = true;
        package = pkgs.skhd;
      };
    };

    # System packages
    environment.systemPackages = [pkgs.skhd];

    # Fonts for sketchybar
    fonts.packages = [
      pkgs.sketchybar-app-font
    ];

    # Hide the default menu bar since we're using sketchybar
    system.defaults.NSGlobalDomain._HIHideMenuBar = true;

    # Debugging configuration - launchd logs for troubleshooting
    launchd.user.agents = {
      yabai.serviceConfig = {
        StandardErrorPath = "/tmp/yabai.err.log";
        StandardOutPath = "/tmp/yabai.out.log";
      };

      sketchybar.serviceConfig = {
        StandardErrorPath = "/tmp/sketchybar.err.log";
        StandardOutPath = "/tmp/sketchybar.out.log";
      };

      skhd.serviceConfig = {
        StandardErrorPath = "/tmp/skhd.err.log";
        StandardOutPath = "/tmp/skhd.out.log";
      };
    };
  };
}
