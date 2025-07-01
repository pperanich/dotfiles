# User module for peranpl1
{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}: let
  cfg = config.my.users.peranpl1;
in {
  options.my.users.peranpl1 = {
    enable = lib.mkEnableOption "peranpl1 user configuration";
  };

  config = lib.mkIf cfg.enable {
    # Common configuration
    users.users.peranpl1 = {
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./id_ed25519.pub)
        (builtins.readFile ../pperanich/id_ed25519.pub)
      ];
      shell = pkgs.zsh;
      packages = [pkgs.home-manager];
    };

    programs.zsh = {
      enable = true;
      enableCompletion = false;
    };

    nix.settings.trusted-users = ["peranpl1"];

    home-manager = {
      # useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit pkgs inputs outputs;
      };
      users.peranpl1.imports = lib.flatten [
        (
          {config, ...}:
            import (lib.my.relativeToRoot "home-manager/peranpl1") {
              inherit pkgs inputs outputs;
            }
        )
      ];
    };
  };
}
