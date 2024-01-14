{ inputs, lib, pkgs, config, modulesPath, ... }:
{

  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };
}

