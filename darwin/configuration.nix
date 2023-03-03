{ pkgs, lib, inputs, outputs, config, ...}:
{
  system.stateVersion = 4;

  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    settings = {
      trusted-users = [ "root" "peranpl1" ];
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      interval = { Day = 7; };
    };
  };

  services = {
    nix-daemon.enable = true;
    yabai = {
      enable = true;
      enableScriptingAddition = true;
      package = pkgs.yabai;
      # config = {
      #   mouse_follows_focus = "off";
      #   focus_follows_mouse = "autofocus";
      #   window_placement = "second_child";
      #   window_topmost = "off";
      #   window_opacity = "off";
      #   window_opacity_duration = 0.0;
      #   window_shadow = "on";
      #   active_window_opacity = 1.0;
      #   normal_window_opacity = 0.90;
      #   split_ratio = 0.50;
      #   auto_balance = "off";
      #   active_window_border_color = "0xff775759";
      #   normal_window_border_color = "0xff555555";
      #   # Mouse support;
      #   mouse_modifier = "alt";
      #   mouse_action_1 = "move";
      #   mouse_action_2 = "resize";
      #   # general space settings;
      #   layout = "bsp";
      #   bottom_padding = 0;
      #   left_padding = 0;
      #   right_padding = 0;
      #   window_gap = 0;
      #   # spacebar padding on top screen
      #   external_bar = "all:26:0";
      # };
      # extraConfig = ''
      #   # float system preferences
      #   yabai -m rule --add app='^System Information$' manage=off
      #   yabai -m rule --add app='^System Preferences$' manage=off
      #   yabai -m rule --add title='Preferences$' manage=off
      #   # float settings windows
      #   yabai -m rule --add title='Settings$' manage=off
      # '';
    };
    skhd = {
      enable = true;
      package = pkgs.skhd;
      # skhdConfig = ''
      #   ####### Shortcut Hotkeys #############
      #   # open terminal
      #   alt - return : open -n /Applications/Alacritty.app
      #
      #   # restart Yabi, SpaceBar, and SKHD
      #   alt + shift - r : \
      #   launchctl kickstart -k "gui/org.nixos.yabai"; \
      #   launchctl kickstart -k "gui/org.nixos.spacebar"; \
      #   skhd --reload
      #
      #
      #   ####### Application Blacklists #############
      #   #.blacklist [
      #   #  "IntelliJ IDEA"
      #   #]
      #
      #
      #   ####### Window Management Hotkeys #############
      #   # change focus
      #   alt - h : yabai -m window --focus west
      #   alt - j : yabai -m window --focus south
      #   alt - k : yabai -m window --focus north
      #   alt - l : yabai -m window --focus east
      #   # (alt) change focus (using arrow keys)
      #   alt - left  : yabai -m window --focus west
      #   alt - down  : yabai -m window --focus south
      #   alt - up    : yabai -m window --focus north
      #   alt - right : yabai -m window --focus east
      #
      #   # shift window in current workspace
      #   alt + shift - h : yabai -m window --swap west || $(yabai -m window --display west; yabai -m display --focus west)
      #   alt + shift - j : yabai -m window --swap south || $(yabai -m window --display south; yabai -m display --focus south)
      #   alt + shift - k : yabai -m window --swap north || $(yabai -m window --display north; yabai -m display --focus north)
      #   alt + shift - l : yabai -m window --swap east || $(yabai -m window --display east; yabai -m display --focus east)
      #   # alternatively, use the arrow keys
      #   alt + shift - left : yabai -m window --swap west || $(yabai -m window --display west; yabai -m display --focus west)
      #   alt + shift - down : yabai -m window --swap south || $(yabai -m window --display south; yabai -m display --focus south)
      #   alt + shift - up : yabai -m window --swap north || $(yabai -m window --display north; yabai -m display --focus north)
      #   alt + shift - right : yabai -m window --swap east || $(yabai -m window --display east; yabai -m display --focus east)
      #
      #   # set insertion point in focused container
      #   alt + ctrl - h : yabai -m window --insert west
      #   alt + ctrl - j : yabai -m window --insert south
      #   alt + ctrl - k : yabai -m window --insert north
      #   alt + ctrl - l : yabai -m window --insert east
      #   # (alt) set insertion point in focused container using arrows
      #   alt + ctrl - left  : yabai -m window --insert west
      #   alt + ctrl - down  : yabai -m window --insert south
      #   alt + ctrl - up    : yabai -m window --insert north
      #   alt + ctrl - right : yabai -m window --insert east
      #
      #   # go back to previous workspace (kind of like back_and_forth in i3)
      #   alt - b : yabai -m space --focus recent
      #
      #   # move focused window to previous workspace
      #   alt + shift - b : yabai -m window --space recent; \
      #   yabai -m space --focus recent
      #
      #   # navigate workspaces next / previous using arrow keys
      #   # cmd - left  : yabai -m space --focus prev
      #   # cmd - right : yabai -m space --focus next
      #
      #   # move focused window to next/prev workspace
      #   alt + shift - 1 : yabai -m window --space 1
      #   alt + shift - 2 : yabai -m window --space 2
      #   alt + shift - 3 : yabai -m window --space 3
      #   alt + shift - 4 : yabai -m window --space 4
      #   alt + shift - 5 : yabai -m window --space 5
      #   alt + shift - 6 : yabai -m window --space 6
      #   alt + shift - 7 : yabai -m window --space 7
      #   alt + shift - 8 : yabai -m window --space 8
      #   alt + shift - 9 : yabai -m window --space 9
      #   #alt + shift - 0 : yabai -m window --space 10
      #
      #   # # mirror tree y-axis
      #   alt + shift - y : yabai -m space --mirror y-axis
      #
      #   # # mirror tree x-axis
      #   alt + shift - x : yabai -m space --mirror x-axis
      #
      #   # balance size of windows
      #   alt + shift - 0 : yabai -m space --balance
      #
      #   # increase window size
      #   alt + shift - a : yabai -m window --resize left:-20:0
      #   alt + shift - s : yabai -m window --resize bottom:0:20
      #   alt + shift - w : yabai -m window --resize top:0:-20
      #   alt + shift - d : yabai -m window --resize right:20:0
      #
      #   # decrease window size
      #   cmd + shift - a : yabai -m window --resize left:20:0
      #   cmd + shift - s : yabai -m window --resize bottom:0:-20
      #   cmd + shift - w : yabai -m window --resize top:0:20
      #   cmd + shift - d : yabai -m window --resize right:-20:0
      #
      #   # change layout of desktop
      #   alt - e : yabai -m space --layout bsp
      #   alt - s : yabai -m space --layout float
      #
      #   # float / unfloat window and center on screen
      #   #alt - t : yabai -m window --toggle float;\
      #   #          yabai -m window --grid 4:4:1:1:2:2
      #   # float / unfloat window and leave in its current location
      #   alt + shift - space : yabai -m window --toggle float
      #   #alt + ctrl - space : yabai -m window --toggle float
      #
      #   # make floating window fill screen
      #   alt + cmd - up     : yabai -m window --grid 1:1:0:0:1:1
      #
      #   # make floating window fill left-half of screen
      #   alt + cmd - left   : yabai -m window --grid 1:2:0:0:1:1
      #
      #   # make floating window fill right-half of screen
      #   alt + cmd - right  : yabai -m window --grid 1:2:1:0:1:1
      #
      #   # create desktop, move window and follow focus
      #   alt + shift + cmd - n : yabai -m space --create;\
      #   index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')"; \
      #   yabai -m window --space "$\{index}";\
      #   yabai -m space --focus "$\{index}"
      #
      #   # create desktop, move window and stay in current workspace
      #   alt + shift - n : yabai -m space --create;\
      #   index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')"; \
      #   yabai -m window --space "$\{index}"
      #
      #   # create desktop and follow focus
      #   # Note: script fails when workspace is empty due to Yabai not reporting the workspace (bug?)
      #   #       best to use the create + move window command instead of creating a blank window
      #   alt - n : yabai -m space --create;\
      #   index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')"; \
      #   yabai -m space --focus "$\{index}"
      #   
      #   # destroy desktop
      #   alt + cmd - w : yabai -m space --destroy
      #   
      #   # close focused window
      #   alt - w : yabai -m window --close
      #   
      #   # toggle sticky
      #   alt + ctrl - s : yabai -m window --toggle sticky
      #   
      #   # enter fullscreen mode for the focused container
      #   alt - f : yabai -m window --toggle zoom-fullscreen
      #   
      #   # toggle window native fullscreen
      #   alt + shift - f : yabai -m window --toggle native-fullscreen
      #   
      #   # focus monitor
      #   alt + ctrl - x  : yabai -m display --focus recent
      #   alt + ctrl - z  : yabai -m display --focus prev
      #   alt + ctrl - c  : yabai -m display --focus next
      #   alt + ctrl - 1  : yabai -m display --focus 1
      #   alt + ctrl - 2  : yabai -m display --focus 2
      #   alt + ctrl - 3  : yabai -m display --focus 3
      #   '';
    };
    spacebar = {
      enable = true;
      package = pkgs.spacebar;
      # config = {
      #   position = "top";
      #   height = 26;
      #   title = "on";
      #   spaces = "on";
      #   clock = "on";
      #   power = "on";
      #   padding_left = 20;
      #   padding_right = 20;
      #   spacing_left = 25;
      #   spacing_right = 15;
      #   text_font = "Iosevka Nerd Font:Bold:12.0";
      #   icon_font = "Iosevka Nerd Font:Regular:12.0";
      #   background_color = "0xff202020";
      #   foreground_color = "0xffa8a8a8";
      #   power_icon_color = "0xffcd950c";
      #   battery_icon_color = "0xffd75f5f";
      #   dnd_icon_color = "0xffa8a8a8";
      #   clock_icon_color = "0xffa8a8a8";
      #   power_icon_strip = " ";
      #   space_icon = "•";
      #   space_icon_color = "0xffffab91";
      #   space_icon_color_secondary = "0xff78c4d4";
      #   space_icon_color_tertiary = "0xfffff9b0";
      #   space_icon_strip = "1 2 3 4 5 6 7 8 9 10";
      #   clock_icon = "";
      #   dnd_icon = "";
      #   clock_format = "%d/%m/%y %R";
      #   right_shell = "on";
      #   right_shell_icon = "";
      #   right_shell_command = "whoami";
      #   debug_output = "on";
      # };
    };
  };

  # For spacebar debugging
  launchd.user.agents.spacebar.serviceConfig.StandardErrorPath = "/tmp/spacebar.err.log";
  launchd.user.agents.spacebar.serviceConfig.StandardOutPath = "/tmp/spacebar.out.log";
  # For yabai debugging
  launchd.user.agents.yabai.serviceConfig.StandardErrorPath = "/tmp/yabai.err.log";
  launchd.user.agents.yabai.serviceConfig.StandardOutPath = "/tmp/yabai.out.log";
  # For skhd debugging
  launchd.user.agents.skhd.serviceConfig.StandardErrorPath = "/tmp/skhd.err.log";
  launchd.user.agents.skhd.serviceConfig.StandardOutPath = "/tmp/skhd.out.log";

  system.defaults = {
    dock = {
      autohide = true;
      showhidden = true;
      mru-spaces = false;
      launchanim = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      QuitMenuItem = true;
    };
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      AppleFontSmoothing = 1;
      _HIHideMenuBar = true;
      InitialKeyRepeat = 10;
      KeyRepeat = 1;
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.swipescrolldirection" = true;
    };
    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  programs.zsh.enable = true;
  users = {
    users.peranpl1 = {
      name = "peranpl1";
      shell = pkgs.zsh;
    };
  };

  launchd.user.envVariables = outputs.homeConfigurations."peranpl1@peranpl1-ml1".config.home.sessionVariables;
}
