{ config, lib, pkgs, ... }:

let
  cfg = config.my.darwin.windowManager.sketchybar;
in
{
  config = lib.mkIf cfg.enable {
    services.sketchybar = {
      enable = true;
      package = pkgs.sketchybar;
      extraPackages = with pkgs; [
        jq
        gh
      ];
      config = ''
        # Bar appearance
        sketchybar --bar height=32 \
                        position=top \
                        padding_left=10 \
                        padding_right=10 \
                        color=0xff1e1e2e \
                        shadow=off \
                        topmost=off

        # Default item settings
        sketchybar --default updates=when_shown \
                            drawing=on \
                            icon.font="JetBrainsMono Nerd Font:Bold:14.0" \
                            icon.color=0xffcdd6f4 \
                            label.font="JetBrainsMono Nerd Font:Bold:14.0" \
                            label.color=0xffcdd6f4 \
                            label.padding_left=4 \
                            label.padding_right=4

        # Left items
        sketchybar --add item apple.logo left \
                   --set apple.logo icon= \
                                   icon.font="JetBrainsMono Nerd Font:Bold:16.0" \
                                   label.drawing=off \
                                   click_script="sketchybar --update"

        # Center items
        sketchybar --add item window.title center \
                   --set window.title script="sketchybar --set \$NAME label=\"\$(yabai -m query --windows --window | jq -r '.app')\""

        # Right items
        sketchybar --add item clock right \
                   --set clock update_freq=10 \
                                script="sketchybar --set \$NAME label=\"\$(date '+%H:%M')\""

        sketchybar --add item battery right \
                   --set battery update_freq=120 \
                                 script="sketchybar --set \$NAME label=\"\$(pmset -g batt | grep -Eo '\\d+%')\""

        # Finalize
        sketchybar --update
      '';
    };
  };

  # environment.systemPackages = [ pkgs.nixcasks.switchaudio-osx ];
  homebrew = {
    brews = [
      "switchaudio-osx"
    ];
  };

  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # For spacebar debugging
  launchd.user.agents.sketchybar.serviceConfig.StandardErrorPath = "/tmp/sketchybar.err.log";
  launchd.user.agents.sketchybar.serviceConfig.StandardOutPath = "/tmp/sketchybar.out.log";
}
