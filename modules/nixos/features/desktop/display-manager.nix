{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.desktop.display-manager;
in {
  options.my.desktop.display-manager = {
    enable = mkEnableOption "Enable display manager configuration";

    defaultSession = mkOption {
      type = types.str;
      default = "sway";
      description = "Default session to use (e.g., 'sway', 'plasma')";
    };

    manager = mkOption {
      type = types.enum ["gdm" "sddm" "lightdm"];
      default = "gdm";
      description = "Display manager to use";
    };

    autoLogin = {
      enable = mkEnableOption "Enable automatic login";
      user = mkOption {
        type = types.str;
        default = "";
        description = "User to automatically log in";
      };
    };
  };

  config = mkIf cfg.enable {
    # Common X11 configuration
    services = {
      # Display Manager Configuration
      displayManager = {
        # Default session configuration
        defaultSession = cfg.defaultSession;

        # Auto login configuration if enabled
        autoLogin = mkIf cfg.autoLogin.enable {
          enable = true;
          user = cfg.autoLogin.user;
        };
      };
      xserver = {

        # Configure the selected display manager
        displayManager.gdm = {
          enable = cfg.manager == "gdm";
          wayland = true;
        };

        displayManager.lightdm = {
          enable = cfg.manager == "lightdm";
          background = "#000000";
          greeters.gtk = {
            enable = true;
            theme = {
              name = "Adwaita";
              package = pkgs.gnome.gnome-themes-extra;
            };
            iconTheme = {
              name = "Adwaita";
              package = pkgs.gnome.adwaita-icon-theme;
            };
          };
        };
      };
    };

    # Install additional packages based on the selected display manager
    environment.systemPackages = with pkgs; (
      if cfg.manager == "sddm"
      then [
        # libsForQt5.plasma-sddm-themes
        # libsForQt5.qt5.qtgraphicaleffects
      ]
      else if cfg.manager == "lightdm"
      then [
        lightdm-gtk-greeter
      ]
      else []
    );
  };
}
