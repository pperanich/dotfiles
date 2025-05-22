# Core module for shared configuration across all systems
{
  inputs,
  config,
  lib,
  ...
}: let
  cfg = config.my.core;
in {
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
    (lib.my.relativeToRoot "modules/shared/core")
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  config = lib.mkIf cfg.enable {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "25.05";

    zramSwap.enable = true;

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
  };
}
