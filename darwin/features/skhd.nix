{ pkgs, lib, inputs, outputs, config, ... }:
let
  inherit (config.users.users.peranpl1) home;
in
{

  environment.systemPackages = [ pkgs.skhd ];

  services = {
    skhd = {
      enable = true;
      package = pkgs.skhd;
    };
  };

  # For skhd debugging
  launchd.user.agents.skhd.serviceConfig.StandardErrorPath = "/tmp/skhd.err.log";
  launchd.user.agents.skhd.serviceConfig.StandardOutPath = "/tmp/skhd.out.log";
}
