{ inputs, outputs, lib, config, pkgs, ... }:
let
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home.packages = with pkgs; [
    xorg.xauth
  ];

  # programs.ssh.enable = true;
  # programs.ssh.extraConfig = ''
  #   Host *
  #     ForwardX11 yes
  #     XAuthLocation ${pkgs.xorg.xauth}/bin/xauth
  #
  #   Include config.d/*
  # '';
}
