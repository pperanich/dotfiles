{ inputs, outputs, lib, config, pkgs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    xorg.xauth
  ];

  programs.ssh.enable = true;
  programs.ssh.extraConfig = ''
    Host *
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Include config.d/*
  '';

  home.file.".ssh/config.d".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/ssh";
}
