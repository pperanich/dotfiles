{ pkgs, config, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.mutableUsers = false;
  users.users.pperanich = {
    initialPassword = "test";
    isNormalUser = true;
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
  programs.zsh.enable = true;

  services.geoclue2.enable = true;
  security.pam.services = { swaylock = { }; };
}
