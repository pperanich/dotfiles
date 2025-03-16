# User module for pperanich
{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}: let
  cfg = config.my.users.pperanich;
in {
  options.my.users.pperanich = {
    enable = lib.mkEnableOption "pperanich user configuration";
  };

  config = lib.mkIf cfg.enable {
    # Common configuration
    users.users.pperanich = {
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./id_ed25519.pub)
        (builtins.readFile ../peranpl1/id_ed25519.pub)
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
            import (lib.my.relativeToRoot "home-manager/pperanich") {
              inherit pkgs inputs outputs;
            }
        )
      ];
    };
  };
}
