# Core module for shared configuration across all systems
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.core;
in {
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
  ];

  options.my.core = {
    enable = lib.mkEnableOption "core system configuration";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Common configuration for all systems
      #   environment.enableAllTerminfo = true;
    })
  ];
}
