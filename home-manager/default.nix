{ inputs, outputs, lib, config, pkgs, ... }:
let
  homePrefix = (if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home");
in
{
  imports = [
    ./global
  ];

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
    };
  };

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    homeDirectory = "/${homePrefix}/${config.home.username}";
  };

  xdg.enable = true;

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git.enable = true;
  programs.git.extraConfig = {
    protocol.file = { allow = "always"; };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.05";
}
