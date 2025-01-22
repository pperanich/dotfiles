{ config, lib, pkgs, ... }:

let
  cfg = config.my.virtualisation;
in
{
  options.my.virtualisation = {
    enable = lib.mkEnableOption "Virtualisation configuration";
    
    docker.enable = lib.mkEnableOption "Docker support";
    podman.enable = lib.mkEnableOption "Podman support";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
    })

    (lib.mkIf cfg.podman.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    })
  ];
} 