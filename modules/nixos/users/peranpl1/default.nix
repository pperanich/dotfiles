# User module for peranpl1
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.my.users.peranpl1;
in {
  imports = [
    (lib.my.relativeToRoot "modules/shared/users/peranpl1")
  ];
  config = lib.mkIf cfg.enable {
    sops.secrets.peranpl1-password = {
      neededForUsers = true;
    };

    users.users.peranpl1 = {
      home = "/home/peranpl1";
      hashedPasswordFile = config.sops.secrets.peranpl1-password.path;
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
