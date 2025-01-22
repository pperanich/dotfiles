{ config, lib, pkgs, ... }:

let
  cfg = config.my.security;
in
{
  options.my.security = {
    enable = lib.mkEnableOption "Security configuration";
    
    yubikey.enable = lib.mkEnableOption "Yubikey support";
    gpg.enable = lib.mkEnableOption "GPG configuration";
    
    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH keys to add to authorized_keys";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.yubikey.enable {
      services.udev.packages = [ pkgs.yubikey-personalization ];
      services.pcscd.enable = true;
    })

    (lib.mkIf cfg.gpg.enable {
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryFlavor = "curses";
      };
    })

    (lib.mkIf cfg.enable {
      # Basic security settings
      security = {
        sudo.enable = true;
        sudo.wheelNeedsPassword = true;
        
        # Harden system
        protectKernelImage = true;
        lockKernelModules = false; # Set to true for more security
      };

      # SSH authorized keys
      users.users.${config.my.user.name}.openssh.authorizedKeys.keys = cfg.sshKeys;
    })
  ];
} 