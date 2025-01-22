{ config, lib, pkgs, ... }:

let
  cfg = config.my.ssh;
in
{
  options.my.ssh = {
    enable = lib.mkEnableOption "SSH configuration";
    
    permitRootLogin = lib.mkOption {
      type = lib.types.enum [ "yes" "no" "prohibit-password" ];
      default = "prohibit-password";
      description = "Whether to allow root login through SSH";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = cfg.permitRootLogin;
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
} 