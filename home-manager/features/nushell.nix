{ inputs, outputs, lib, config, pkgs, ... }:
{
  programs = {
    nushell = {
      enable = true;
    };
    direnv = {
      enableNushellIntegration = true;
    };
    atuin = {
      enableNushellIntegration = true;
    };
    zoxide = {
      enableNushellIntegration = true;
    };
  };
}

