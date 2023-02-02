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
        position=top \
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
# config = ''
      #   #!/bin/bash
      #   bar_color=0xff2e3440
      #   # bar_color=0x30000000
      #   icon_font="JetBrainsMono Nerd Font:Medium:16.0"
      #   icon_color=0xbbd8dee9
      #   icon_highlight_color=0xffebcb8b
      #   label_font="$icon_font"
      #   label_color="$icon_color"
      #   label_highlight_color="$icon_highlight_color"
      #   spaces=()
      #   for i in {1..8}
      #   do
      #   spaces+=(--add space space$i left \
      #       --set space$i \
      #       associated_display=1 \
      #       associated_space=$i \
      #       icon=$i \
      #       click_script="yabai -m space --focus $i" \
      #       script=${scripts}/space.sh)
      #           done
      #           sketchybar -m \
      #           --bar \
      #           height=24 \
      #           position=top \
      #           sticky=on \
      #           shadow=on \
      #           padding_left=10 \
      #           padding_right=10 \
      #           color="$bar_color" \
      #           --default \
      #           icon.font="$icon_font" \
      #           icon.color="$icon_color" \
      #           icon.highlight_color="$icon_highlight_color" \
      #           label.font="$label_font" \
      #           label.color="$label_color" \
      #           label.highlight_color="$label_highlight_color" \
      #           icon.padding_left=10 \
      #           icon.padding_right=6 \
      #           --add item title center \
      #           --set title script='sketchybar --set "$NAME" label="$INFO"' \
      #           --subscribe title front_app_switched \
      #           --add item clock right \
      #           --set clock update_freq=10 script="${scripts}/status.sh" icon.padding_left=2 \
      #           --add item battery right \
      #           --set battery update_freq=60 script="${scripts}/battery.sh" \
      #           --add item wifi right \
      #           --set wifi click_script="${scripts}/click-wifi.sh" \
      #           --add item load right \
      #           --set load icon="􀍽" script="${scripts}/window-indicator.sh" \
      #           --subscribe load space_change \
      #           --add item network right \
      #           --add item input right \
      #           --add event input_change 'AppleSelectedInputSourcesChangedNotification' \
      #           --subscribe input input_change \
      #           --set input script="${scripts}/input.sh" label.padding_right=-8 \
      #           --default \
      #           icon.padding_left=0 \
      #           icon.padding_right=2 \
      #           label.padding_right=16 \
      #           "''${spaces[@]}"
      #           sketchybar --update
      #           # ram disk
      #           cache="$HOME/.cache/sketchybar"
      #           mkdir -p "$cache"
      #           if ! mount | grep -qF "$cache"
      #             then
      #               disk=$(hdiutil attach -nobrowse -nomount ram://1024)
      #               disk="''${disk%% *}"
      #               newfs_hfs -v sketchybar "$disk"
      #               mount -t hfs -o nobrowse "$disk" "$cache"
      #               fi
      #               '';
    };
  };
  services.yabai.config.external_bar = "main:24:0";
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # For spacebar debugging
  launchd.user.agents.sketchybar.serviceConfig.StandardErrorPath = "/tmp/sketchybar.err.log";
  launchd.user.agents.sketchybar.serviceConfig.StandardOutPath = "/tmp/sketchybar.out.log";
}
