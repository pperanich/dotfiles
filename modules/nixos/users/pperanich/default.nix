# User module for pperanich
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.my.users.pperanich;
in {
  imports = lib.flatten [
    (lib.my.relativeToRoot "modules/shared/users/pperanich")
  ];
  config = lib.mkIf cfg.enable {
      sops.secrets.pperanich-password = {
        neededForUsers = true;
      };

      users.users.pperanich = {
        home = "/home/pperanich";
        hashedPasswordFile = config.sops.secrets.pperanich-password.path;
        isNormalUser = true;
        extraGroups =
          [
            "wheel"
            "video"
            "audio"
          ]
          ++ (builtins.filter (group: builtins.hasAttr group config.users.groups) [
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
      security.pam.services = {swaylock = {};};
    };
}
