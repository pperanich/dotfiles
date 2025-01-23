# User module for pperanich
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.modules.users.pperanich;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  options.modules.users.pperanich = {
    enable = lib.mkEnableOption "pperanich user configuration";
    darwin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = isDarwin;
        description = "Whether to enable Darwin-specific features for pperanich";
      };
    };
    nixos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = !isDarwin;
        description = "Whether to enable NixOS-specific features for pperanich";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Common configuration
      users.users.pperanich = {
        name = "pperanich";
        openssh.authorizedKeys.keys = [
          (builtins.readFile ./id_ed25519.pub)
        ];
        shell = pkgs.zsh;
        packages = [ pkgs.home-manager ];
      };

      programs.zsh.enable = true;
      nix.settings.trusted-users = [ "pperanich" ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs inputs;
        };
        users.pperanich.imports = lib.flatten ([
          ({ config, ... }:
            import (lib.custom.relativeToRoot "home-manager/pperanich") {
              inherit pkgs inputs config lib;
            }
          )
        ]);
      };
    })

    # Darwin-specific configuration
    (lib.mkIf (cfg.enable && cfg.darwin.enable && isDarwin) {
      users.users.pperanich = {
        home = "/Users/pperanich";
      };

      launchd.user.envVariables = config.home-manager.users.pperanich.home.sessionVariables;
    })

    # NixOS-specific configuration
    (lib.mkIf (cfg.enable && cfg.nixos.enable && !isDarwin) {
      sops.secrets.pperanich-password = {
        neededForUsers = true;
      };

      users.users.pperanich = {
        home = "/home/pperanich";
        hashedPasswordFile = config.sops.secrets.pperanich-password.path;
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "audio"
        ] ++ (builtins.filter (group: builtins.hasAttr group config.users.groups) [
          "network"
          "wireshark"
          "i2c"
          "mysql"
          "docker"
          "podman"
          "git"
        ]);
      };

      programs = {
        nix-ld.enable = true;
        nix-ld.libraries = with pkgs; [
          # Add any missing dynamic libraries for unpackaged programs
          # here, NOT in environment.systemPackages
        ];
      };

      services.geoclue2.enable = true;
      security.pam.services = { swaylock = { }; };
    })
  ];
} 