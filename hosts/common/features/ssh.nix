{ inputs, lib, pkgs, config, modulesPath, ... }:
{

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };
}

