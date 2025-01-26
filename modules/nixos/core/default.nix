# Core module for shared configuration across all systems
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.core;
in {
  imports = [
    # lib.my.relativeToRoot "modules/shared/core"
    ../../shared/core
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  config = lib.mkMerge [
    # NixOS-specific configuration
    (lib.mkIf cfg.enable {
      #   boot.tmp.cleanOnBoot = true;
      zramSwap.enable = true;

      services = {
        openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };
      };

      # Increase open file limit for sudoers
      security.pam.loginLimits = [
        {
          domain = "@wheel";
          item = "nofile";
          type = "soft";
          value = "524288";
        }
        {
          domain = "@wheel";
          item = "nofile";
          type = "hard";
          value = "1048576";
        }
      ];
    })
  ];
}
