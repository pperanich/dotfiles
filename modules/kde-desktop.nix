_: {
  # KDE Plasma desktop environment - Full-featured desktop environment
  flake.modules.nixos.kdeDesktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # Enable X11 and display manager
    services.xserver.enable = true;

    # Configure SDDM display manager with Wayland support
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # Enable KDE Plasma 6 desktop environment
    services.desktopManager.plasma6.enable = true;

    # Essential packages for enhanced KDE experience
    environment.systemPackages = with pkgs; [
      polonium # Tiling window manager for KDE

      # Additional KDE applications that users commonly need
      kate # Advanced text editor
      okular # Document viewer
      gwenview # Image viewer
      dolphin # File manager (usually included with Plasma)
      konsole # Terminal emulator (usually included with Plasma)

      # System utilities for KDE
      partitionmanager # Disk partitioning tool
      kcalc # Calculator

      # Multimedia support
      vlc # Media player

      # Archive support
      ark # Archive manager

      # Network tools
      networkmanager-qt # NetworkManager frontend for Qt
    ];

    # Audio support (PipeWire is recommended for modern KDE)
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Enable CUPS for printing
    services.printing.enable = lib.mkDefault true;

    # Enable sound with PulseAudio (will be handled by PipeWire)
    # hardware.pulseaudio.enable = false; # Explicitly disabled for PipeWire

    # Configure fonts for better KDE experience
    fonts = {
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        liberation_ttf
        fira-code
        fira-code-symbols
        font-awesome
        powerline-fonts
      ];
      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = ["Noto Serif"];
          sansSerif = ["Noto Sans"];
          monospace = ["Fira Code"];
        };
      };
    };

    # Enable dbus for KDE integration
    services.dbus.enable = true;

    # Configure session variables for KDE
    environment.sessionVariables = {
      # Qt/KDE specific
      QT_QPA_PLATFORMTHEME = "kde";

      # Wayland support for Qt applications
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # General desktop environment
      XDG_CURRENT_DESKTOP = "KDE";
    };

    # Enable Wayland support for applications
    environment.variables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };
  };

  # User-level KDE configuration
  flake.modules.homeModules.kdeDesktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # User session variables for KDE
    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "kde";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      XDG_CURRENT_DESKTOP = "KDE";
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };

    # User packages for enhanced KDE experience
    home.packages = with pkgs; [
      # KDE Connect for device integration
      kdeconnect

      # Additional development tools that work well with KDE
      krdc # Remote desktop client

      # Plasma widgets and extensions
      latte-dock # Dock for Plasma (if user wants it)

      # Theme and customization tools
      kvantum # SVG-based theme engine for Qt

      # Additional utilities
      spectacle # Screenshot tool (usually included with Plasma)
      kcolorchooser # Color picker
      kruler # Screen ruler

      # File management enhancements
      kio-extras # Additional KIO workers for Dolphin
    ];

    # Configure Qt applications to use KDE theme
    qt = {
      enable = true;
      platformTheme = "kde";
    };

    # Configure GTK to match KDE theme (for better integration)
    gtk = {
      enable = true;
      theme = {
        name = "Breeze";
        package = pkgs.kdePackages.breeze-gtk;
      };
      iconTheme = {
        name = "breeze";
        package = pkgs.kdePackages.breeze-icons;
      };
    };

    # Enable XDG desktop integration
    xdg = {
      enable = true;
      mimeApps.enable = true;
    };
  };
}
