_: {
  # Hyprland Wayland compositor - Modern tiling window manager
  flake.modules.nixos.hyprlandDesktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # Enable Hyprland window manager
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    # XDG portal with Wayland support
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    # Audio and screen sharing support
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # GNOME keyring for credential management
    services.gnome.gnome-keyring.enable = true;

    # Essential packages for Hyprland desktop environment
    environment.systemPackages = with pkgs; [
      # Core Hyprland utilities
      waybar # status bar
      wofi # application launcher
      mako # notification daemon
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
    ];

    # Configure fonts for desktop environment
    fonts.packages = with pkgs; [
      noto-fonts
      font-awesome
    ];

    # Environment variables for Wayland compatibility
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

  # User-level Hyprland configuration
  flake.modules.homeModules.hyprlandDesktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # Wayland session variables for user session
    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      NIXOS_OZONE_WL = "1";
    };

    # User packages for enhanced Hyprland experience
    home.packages = with pkgs; [
      # Additional Wayland tools
      wtype # Wayland text input
      wf-recorder # Wayland screen recorder

      # Additional desktop utilities that users might want
      pavucontrol # PulseAudio volume control
      networkmanagerapplet # Network manager tray
    ];

    # Enable Wayland support in user applications
    programs.firefox.package = pkgs.firefox-wayland;

    # Configure file manager with Wayland support
    programs.thunar = {
      enable = lib.mkDefault false; # Users can enable if needed
    };
  };
}
