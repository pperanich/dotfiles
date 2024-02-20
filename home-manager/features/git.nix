{ inputs, outputs, lib, config, pkgs, ... }:
{
  programs.git.enable = true;
  programs.git.extraConfig = {
    protocol.file = { allow = "always"; };
  };
  programs.git.lfs.enable = true;
}
