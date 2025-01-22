{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  sops.secrets.pperanich-password = {
    neededForUsers = true;
  };

  users = {
    users.pperanich = {
      home = "/home/pperanich";
      hashedPasswordFile = config.sops.secrets.pperanich-password.path;
      isNormalUser = true;
      extraGroups = [
        "wheel"
          "video"
          "audio"
      ] ++ ifTheyExist [
      "network"
        "wireshark"
        "i2c"
        "mysql"
        "docker"
        "podman"
        "git"
      ];
    };
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
}