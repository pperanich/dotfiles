{ pkgs, config, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users = {
    mutableUsers = false;
    users.pperanich = {
      initialPassword = "test";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        (builtins.readFile ../../../../secrets/id_rsa.pub)
      ];
      shell = pkgs.zsh;
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
      packages = [ pkgs.home-manager ];
    };
  };
  programs = {
    zsh.enable = true;
    nix-ld.enable = true;
    nix-ld.libraries = with pkgs; [
      # Add any missing dynamic libraries for unpackaged programs
      # here, NOT in environment.systemPackages
    ];
  };

  services.geoclue2.enable = true;
  security.pam.services = { swaylock = { }; };
}
