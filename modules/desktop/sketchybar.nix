# Sketchybar status bar and jankyborders
_: {
  flake.modules.darwin.sketchybar =
    { config, pkgs, ... }:
    let
      inherit (config.system) primaryUser;
      homeDir = config.home-manager.users.${primaryUser}.home.homeDirectory;
    in
    {
      services.sketchybar = {
        enable = true;
        package = pkgs.sketchybar;
        extraPackages = [
          pkgs.sketchybar-helpers
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
        # With order=above, borders draw over macOS auth sheets, which stops them
        # taking key focus. The App Store password sheet then dismisses itself with
        # AMSErrorDomain code=6 and purchases fail with no visible error.
        blacklist = [
          "App Store"
          "AMSUIPaymentViewService_macOS"
        ];
      };

      environment.systemPackages = [
        (pkgs.lua5_5.withPackages (_: [
          pkgs.sbarlua
        ]))
      ];

      fonts.packages = [
        pkgs.sketchybar-app-font
      ];

      # Store SketchyBar logs in user-private ~/Library/Logs instead of world-readable /tmp
      launchd.user.agents.sketchybar.serviceConfig = {
        StandardErrorPath = "${homeDir}/Library/Logs/sketchybar.err.log";
        StandardOutPath = "${homeDir}/Library/Logs/sketchybar.out.log";
      };
    };
}
