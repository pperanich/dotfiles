_: {
  # Sway Wayland compositor - i3-compatible Wayland compositor
  flake.modules.nixos.swayDesktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # Enable Sway window manager with GTK wrapper features
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true; # Ensure GTK applications work properly
      extraPackages = with pkgs; [
        # Core Sway utilities
        swaylock # Screen locker
        swayidle # Idle daemon
        wl-clipboard # Clipboard manager
        mako # Notification daemon
        alacritty # Terminal
        wofi # Application launcher
        waybar # Status bar

        # Screenshot and display tools
        grim # Screenshot functionality
        slurp # Screen area selection
        kanshi # Display configuration daemon

        # Wayland session utilities
        wayland # Core Wayland libraries
        xdg-utils # XDG utilities
        glib # GLib utilities

        # Theming and icons
        whitesur-icon-theme
        capitaine-cursors
      ];
    };

    # Enable brightness control
    programs.light.enable = true;

    # XDG portal with Wayland support
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    # Audio and screen sharing support
    security.rtkit.enable = true;
    services = {
      dbus.enable = true;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };
      # GNOME keyring for credential management
      gnome.gnome-keyring.enable = true;
    };

    # Kanshi systemd service for display management
    systemd.user.services.kanshi = {
      description = "kanshi daemon";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kanshi}/bin/kanshi -c kanshi_config_file";
      };
    };

    # Supporting packages for a better Wayland experience
    environment.systemPackages = with pkgs; [
      # Wayland utilities
      wev # Wayland event viewer
      wlr-randr # Wayland randr equivalent

      # File management and utilities
      xdg-utils
      qt5.qtwayland
      qt6.qtwayland

      # Theming
      adwaita-qt
      gtk-engine-murrine
      gtk_engines
      gsettings-desktop-schemas
      lxappearance # GTK theme configuration
    ];

    # Configure fonts for desktop environment
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      fira-code
      fira-code-symbols
    ];

    # Environment variables for Wayland compatibility
    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      NIXOS_OZONE_WL = "1";
    };
  };

  # User-level Sway configuration
  flake.modules.homeModules.swayDesktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # Wayland session variables for user session
    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      NIXOS_OZONE_WL = "1";
    };

    # User packages for enhanced Sway experience
    home.packages = with pkgs; [
      # Additional Wayland tools
      wtype # Wayland text input
      wf-recorder # Wayland screen recorder

      # Desktop utilities
      pavucontrol # PulseAudio volume control
      networkmanagerapplet # Network manager tray
      blueman # Bluetooth manager

      # File management
      pcmanfm # Lightweight file manager
      thunar # Alternative file manager

      # Media and graphics
      imv # Image viewer for Wayland
      mpv # Media player

      # System monitoring
      htop # Process viewer

      # Additional development and productivity tools
      firefox-wayland # Firefox with native Wayland support
    ];

    # Configure Sway directly (users can override)
    wayland.windowManager.sway = {
      enable = lib.mkDefault false; # Users need to explicitly enable
      config = lib.mkIf config.wayland.windowManager.sway.enable {
        modifier = "Mod4"; # Super key
        terminal = "alacritty";
        menu = "wofi --show drun";

        # Basic keybindings
        keybindings = lib.mkOptionDefault {
          # Screenshot bindings
          "Print" = "exec grim - | wl-copy";
          "Shift+Print" = "exec grim -g \"$(slurp)\" - | wl-copy";

          # Volume control
          "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

          # Brightness control
          "XF86MonBrightnessUp" = "exec light -A 10";
          "XF86MonBrightnessDown" = "exec light -U 10";
        };

        # Default workspaces on outputs
        workspaceOutputAssign = [
          {
            workspace = "1";
            output = "eDP-1";
          }
          {
            workspace = "2";
            output = "eDP-1";
          }
        ];

        # Status bar configuration
        bars = [
          {
            command = "waybar";
          }
        ];

        # Window rules
        window.commands = [
          {
            criteria = {app_id = "pavucontrol";};
            command = "floating enable";
          }
          {
            criteria = {app_id = "blueman-manager";};
            command = "floating enable";
          }
        ];
      };
    };

    # Configure supporting applications
    programs.waybar = {
      enable = lib.mkDefault false; # Users can enable and configure
    };

    programs.wofi = {
      enable = lib.mkDefault false; # Users can enable and configure
    };

    services.mako = {
      enable = lib.mkDefault false; # Users can enable and configure
    };
  };
}
