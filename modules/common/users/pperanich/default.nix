# User module for pperanich
{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}: let
  cfg = config.modules.users.pperanich;
in {
  options.modules.users.pperanich = {
    enable = lib.mkEnableOption "pperanich user configuration";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Common configuration
      users.users.pperanich = {
        openssh.authorizedKeys.keys = [
          (builtins.readFile ./id_ed25519.pub)
        ];
        shell = pkgs.zsh;
        packages = [pkgs.home-manager];
      };

      programs.zsh.enable = true;
      nix.settings.trusted-users = ["pperanich"];

      home-manager = {
        # useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs inputs outputs;
        };
        users.pperanich.imports = lib.flatten [
          (
            {config, ...}:
              import (lib.custom.relativeToRoot "home-manager/pperanich") {
                inherit pkgs inputs outputs;
              }
          )
        ];
      };
    })
  ];
}
