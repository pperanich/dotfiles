{ inputs, lib, pkgs, config, modulesPath, ... }:
{
  # make the tailscale command usable to users
  environment.systemPackages = [ pkgs.tailscale ];

  services.tailscale = {
    enable = true;
  };
}
