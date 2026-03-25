# Sketchybar status bar and jankyborders
_: {
  flake.modules.darwin.sketchybar =
    { pkgs, ... }:
    {
      services.sketchybar = {
        enable = true;
        package = pkgs.sketchybar;
        extraPackages = [
          pkgs.switchaudio-osx
        ];
      };

      services.jankyborders = {
        enable = true;
        width = 1.0; # Matches workspace border_width
        hidpi = true;
        order = "above";
        active_color = "0xFFfab387"; # Catppuccin peach (matches active workspace)
        inactive_color = "0xFF45475a"; # Catppuccin surface1
        style = "round";
      };

      environment.systemPackages = [
        (pkgs.lua5_5.withPackages (_: [
          pkgs.sbarlua
        ]))
      ];

      fonts.packages = [
        pkgs.sketchybar-app-font
      ];

      system.defaults.NSGlobalDomain._HIHideMenuBar = true;

      # For sketchybar debugging
      launchd.user.agents.sketchybar.serviceConfig.StandardErrorPath = "/tmp/sketchybar.err.log";
      launchd.user.agents.sketchybar.serviceConfig.StandardOutPath = "/tmp/sketchybar.out.log";
    };
}
