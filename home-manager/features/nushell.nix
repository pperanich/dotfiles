{ inputs, outputs, lib, config, pkgs, ... }:
{
  programs.nushell = {
    enable = true;
  };
  programs.direnv = {
    enableNushellIntegration = true;
  };
  programs.atuin = {
    enableNushellIntegration = true;
  };
  programs.zoxide = {
    enableNushellIntegration = true;
  };
}

