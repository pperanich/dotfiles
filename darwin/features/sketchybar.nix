{ pkgs, lib, inputs, outputs, config, ...}:
let
scripts = ./scripts;
in
{
  services = {
    sketchybar = {
      enable = true;
      package = pkgs.sketchybar;
      config = ''
        sketchybar --bar height=32 \
        blur_radius=30 \
        position=bottom \
        sticky=off \
        padding_left=10 \
        padding_right=10 \
        color=0x15ffffff
        sketchybar --default icon.font="Iosevka Nerd Font:Bold:17.0" \
        icon.color=0xffffffff \
        label.font="Iosevka Nerd Font:Bold:14.0" \
        label.color=0xffffffff \
        padding_left=5 \
        padding_right=5 \
        label.padding_left=4 \
        label.padding_right=4 \
        icon.padding_left=4 \
        icon.padding_right=4

        SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")
        for i in "''${!SPACE_ICONS[@]}"
          do
            sid=$(($i+1))
              sketchybar --add space space.$sid left \
              --set space.$sid associated_space=$sid \
              icon=''${SPACE_ICONS[i]}                     \
              background.color=0x44ffffff \
              background.corner_radius=5 \
              background.height=20 \
              background.drawing=off \
              label.drawing=off \
              script="${scripts}/space.sh" \
              click_script="yabai -m space --focus $sid"
        done

        sketchybar --add item space_separator left \
        --set space_separator icon= \
        padding_left=10 \
        padding_right=10 \
        label.drawing=off \
        --add item front_app left \
        --set front_app       script="${scripts}/front_app.sh" \
        icon.drawing=off \
        --subscribe front_app front_app_switched

        sketchybar --add item clock right \
        --set clock   update_freq=10 \
        icon= \
        script="${scripts}/clock.sh" \
        --add item wifi right \
        --set wifi    script="${scripts}/wifi.sh" \
        icon=直 \
        --subscribe wifi wifi_change \
        --add item volume right \
        --set volume  script="${scripts}/volume.sh" \
        --subscribe volume volume_change \
        --add item battery right \
        --set battery script="${scripts}/battery.sh" \
        update_freq=120 \
        --subscribe battery system_woke power_source_change
        sketchybar --update
              '';
    };
  };
  services.yabai.config.external_bar = "all:0:32";
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # For spacebar debugging
  launchd.user.agents.sketchybar.serviceConfig.StandardErrorPath = "/tmp/sketchybar.err.log";
  launchd.user.agents.sketchybar.serviceConfig.StandardOutPath = "/tmp/sketchybar.out.log";
}
