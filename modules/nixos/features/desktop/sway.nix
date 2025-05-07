{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.desktop.sway;
in {
  options.my.desktop.sway = {
    enable = mkEnableOption "Enable Sway Wayland compositor";

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install for Sway";
    };
  };

  config = mkIf cfg.enable {
    # Enable Sway window manager
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true; # so that gtk works properly
      extraPackages = with pkgs;
        [
          swaylock
          swayidle
          wl-clipboard
          mako # notification daemon
          alacritty # terminal
          wofi # application launcher
          waybar # status bar
          grim # screenshot functionality
          slurp # screen area selection
          kanshi # autorandr alternative for wayland
          sway
          # dbus-sway-environment
          # configure-gtk
          wayland
          xdg-utils
          glib
          whitesur-icon-theme
          capitaine-cursors
        ]
        ++ cfg.extraPackages;
    };

    programs.light.enable = true;

    services.dbus.enable = true;

    # XDG portal with Wayland support
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };

    # Needed for screen sharing and pipewire
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    services.gnome.gnome-keyring.enable = true;

    # kanshi systemd service
    systemd.user.services.kanshi = {
      description = "kanshi daemon";
      serviceConfig = {
        Type = "simple";
        ExecStart = ''${pkgs.kanshi}/bin/kanshi -c kanshi_config_file'';
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

      # Theming
      adwaita-qt
      gtk-engine-murrine
      gtk_engines
      gsettings-desktop-schemas
      lxappearance
    ];

    # Configure fonts
    fonts.packages = with pkgs; [
      noto-fonts
      font-awesome
    ];

    # Environment variables for Wayland
    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };
}
