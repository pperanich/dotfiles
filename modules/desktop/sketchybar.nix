# Sketchybar status bar
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

      environment.systemPackages = [
        (pkgs.lua5_4.withPackages (_: [
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
