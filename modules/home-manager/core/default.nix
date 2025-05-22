# Core home-manager configuration
{
  config,
  lib,
  pkgs,
  outputs,
  inputs,
  ...
}: let
  cfg = config.my.home;
  homePrefix =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "Users"
    else "home";
in {
  imports = [
    ./shell.nix
    inputs.nix-index-database.hmModules.nix-index
  ];

  options.my.home = {
    enable = lib.mkEnableOption "home-manager core configuration";
  };

  config = lib.mkIf cfg.enable {
    # Basic home-manager configuration
    home = {
      homeDirectory = "/${homePrefix}/${config.home.username}";
      stateVersion = "25.05";
      sessionPath = ["${config.home.homeDirectory}/.local/bin"];
      sessionVariables = {
        FLAKE = "${config.home.homeDirectory}/dotfiles/";
      };
    };

    xdg.enable = true;

    # Default programs
    programs = {
      home-manager.enable = true;
      pandoc.enable = true;
      gpg.enable = true;
      dircolors.enable = true;
      direnv.enable = true;
      atuin.enable = true;
      zoxide.enable = true;
      nix-index-database.comma.enable = true;
    };

    nixpkgs = {
      overlays = builtins.attrValues outputs.overlays;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
        packageOverrides = _: {
          nixcasks = import inputs.nixcasks {
            inherit pkgs;
            osVersion = "sequoia";
          };
        };
      };
    };
  };
}
