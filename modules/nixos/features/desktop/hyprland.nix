{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.desktop.hyprland;
in {
  options.my.desktop.hyprland = {
    enable = mkEnableOption "Enable Hyprland Wayland compositor";

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install for Hyprland";
    };
  };

  config = mkIf cfg.enable {
    # Enable Hyprland window manager
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    # programs.light.enable = true;

    # XDG portal with Wayland support
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    # Needed for screen sharing and pipewire
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    services.gnome.gnome-keyring.enable = true;

    # Essential packages for Hyprland
    environment.systemPackages = with pkgs;
      [
        # Core Hyprland utilities
        waybar # status bar
        wofi # application launcher
        mako # notification daemon
        # swww # wallpaper daemon for Hyprland
        wl-clipboard # clipboard manager
        alacritty # terminal

        # Display management
        wlr-randr # Wayland randr equivalent
        kanshi # autorandr alternative for wayland

        # Screenshot and screen recording
        grim # screenshot functionality
        slurp # screen area selection

        # Wayland utilities
        wev # Wayland event viewer
        wlogout # logout menu

        # File management and utilities
        xdg-utils
        qt5.qtwayland
        qt6.qtwayland

        # Theming
        adwaita-qt
        gtk-engine-murrine
        gtk_engines
        gsettings-desktop-schemas
        lxappearance
      ]
      ++ cfg.extraPackages;

    # Configure fonts
    fonts.packages = with pkgs; [
      noto-fonts
      font-awesome
      # nerd-fonts.JetBrainsMono
      # nerd-fonts.FiraCode
    ];

    # Environment variables for Wayland
    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      NIXOS_OZONE_WL = "1";
    };
  };
}
