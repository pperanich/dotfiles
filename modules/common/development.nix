{ config, lib, pkgs, ... }:

let
  cfg = config.my.development;
in
{
  options.my.development = {
    enable = lib.mkEnableOption "Development configuration";
    
    ccache.enable = lib.mkEnableOption "CCache support";
    android.enable = lib.mkEnableOption "Android development support";
    ios.enable = lib.mkEnableOption "iOS development support";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.ccache.enable {
      programs.ccache = {
        enable = true;
        packageNames = [ "gcc" "clang" ];
      };
    })

    (lib.mkIf cfg.android.enable {
      programs.adb.enable = true;
      users.users.${config.my.user.name}.extraGroups = [ "adbusers" ];
      environment.systemPackages = with pkgs; [
        android-studio
        android-tools
      ];
    })

    (lib.mkIf (cfg.ios.enable && pkgs.stdenv.isDarwin) {
      environment.systemPackages = with pkgs; [
        cocoapods
      ];
    })

    (lib.mkIf cfg.enable {
      # Common development packages
      environment.systemPackages = with pkgs; [
        git
        git-lfs
        gnumake
        gcc
        pkg-config
      ];
    })
  ];
} 