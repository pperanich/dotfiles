{ inputs, lib, pkgs, config, modulesPath, ... }:
{

  services.openssh = {
    enable = true;
    ports = [ 22 3000 ];
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };
}

