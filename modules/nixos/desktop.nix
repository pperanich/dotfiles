{ config, lib, pkgs, ... }:

let
  cfg = config.my.nixos.desktop;
in
{
  options.my.nixos.desktop = {
    enable = lib.mkEnableOption "NixOS desktop configuration";
    
    gnome.enable = lib.mkEnableOption "GNOME desktop environment";
    kde.enable = lib.mkEnableOption "KDE desktop environment";
    
    displayManager = lib.mkOption {
      type = lib.types.enum [ "gdm" "sddm" "lightdm" ];
      default = "gdm";
      description = "Display manager to use";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.gnome.enable {
      services.xserver = {
        enable = true;
        displayManager.gdm.enable = cfg.displayManager == "gdm";
        desktopManager.gnome.enable = true;
      };

      environment.gnome.excludePackages = with pkgs.gnome; [
        epiphany    # web browser
        totem       # video player
        geary       # email client
      ];
    })

    (lib.mkIf cfg.kde.enable {
      services.xserver = {
        enable = true;
        displayManager.sddm.enable = cfg.displayManager == "sddm";
        desktopManager.plasma5.enable = true;
      };
    })

    (lib.mkIf cfg.enable {
      # Common desktop configuration
      services.xserver = {
        enable = true;
        layout = "us";
        libinput.enable = true;
      };

      # Sound
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # Common packages
      environment.systemPackages = with pkgs; [
        firefox
        alacritty
        _1password-gui
      ];
    })
  ];
} 