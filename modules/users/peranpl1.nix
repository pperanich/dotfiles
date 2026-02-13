_:
let
  sopsFolder = ../../sops;
in
{
  # peranpl1 user configuration - both NixOS system user and home-manager setup
  flake.modules.nixos.peranpl1 =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # Deploy SSH private key via system-level sops BEFORE home-manager runs
      sops.secrets."private_keys/peranpl1" = {
        sopsFile = "${sopsFolder}/secrets.yaml";
        owner = "peranpl1";
        group = "users";
        mode = "0400";
        path = "/home/peranpl1/.ssh/id_ed25519";
      };

      # Create system user
      users.users.peranpl1 = {
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
        shell = pkgs.zsh;
        packages = [ pkgs.home-manager ];
        extraGroups = [ "keys" ];
      };

      # Enable zsh system-wide
      programs.zsh = {
        enable = true;
        enableCompletion = false;
      };

      # Add to trusted users for nix
      nix.settings.trusted-users = [ "peranpl1" ];

      # Configure home-manager for this user
      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs;
        };
        users.peranpl1.imports = lib.flatten [
          (
            _:
            import (lib.my.relativeToRoot "home-profiles/peranpl1") {
              inherit (config.flake.modules) homeManager;
              config = config.home-manager.users.peranpl1;
            }
          )
        ];
      };
    };

  # Darwin system user configuration
  flake.modules.darwin.peranpl1 =
    {
      config,
      pkgs,
      lib,
      modules,
      ...
    }:
    {
      # Deploy SSH private key via system-level sops BEFORE home-manager runs
      sops.secrets."private_keys/peranpl1" = {
        sopsFile = "${sopsFolder}/secrets.yaml";
        owner = "peranpl1";
        group = "staff";
        mode = "0400";
        path = "/Users/peranpl1/.ssh/id_ed25519";
      };

      # Create system user
      users.users.peranpl1 = {
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
        shell = pkgs.zsh;
        packages = [ pkgs.home-manager ];
        home = "/Users/peranpl1";
      };

      system.primaryUser = "peranpl1";

      launchd.user.envVariables = config.home-manager.users.peranpl1.home.sessionVariables;

      # Add to trusted users for nix
      nix.settings.trusted-users = [ "peranpl1" ];

      # Configure home-manager for this user
      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs;
        };
        users.peranpl1.imports = lib.flatten [
          (
            _:
            import (lib.my.relativeToRoot "home-profiles/peranpl1") {
              inherit (modules) homeManager;
              config = config.home-manager.users.peranpl1;
            }
          )
        ];
      };
    };
}
