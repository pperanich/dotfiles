{ inputs, lib, pkgs, config, modulesPath, ... }:
{
  services.openssh = {
    enable = true;
  };
}

